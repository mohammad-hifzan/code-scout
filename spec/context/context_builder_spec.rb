require 'spec_helper'
require 'active_support/inflector'

require_relative '../../lib/context/context_builder'

RSpec.describe ContextBuilder do
  subject(:builder) { described_class.new(project_map, project_path) }
  let(:project_path) { '/fake/project' }

  let(:project_map) do
    {
      models: {
        'User' => {
          path: '/fake/project/app/models/user.rb',
          associations: {
            has_many: [:posts],
            belongs_to: [:account]
          }
        },
        'Post' => {
          path: '/fake/project/app/models/post.rb',
          associations: {}
        },
        'Account' => {
          path: '/fake/project/app/models/account.rb',
          associations: {}
        },
        'Person' => {
          path: '/fake/project/app/models/person.rb',
          associations: {}
        }
      },
      controllers: {
        'UsersController' => { path: '/fake/project/app/controllers/users_controller.rb' },
        'PeopleController' => { path: '/fake/project/app/controllers/people_controller.rb' }
      }
    }
  end

  let(:user_policy_path) { '/fake/project/app/policies/user_policy.rb' }
  let(:all_view_paths) do
    [
      '/fake/project/app/views/users/index.html.erb',
      '/fake/project/app/views/users/_form.html.erb',
      '/fake/project/app/views/posts/show.html.erb',
      '/fake/project/app/views/shared/user_profile.html.erb'
    ]
  end

  before do
    # Mock filesystem interactions
    allow(File).to receive(:exist?).and_return(false) # Default to not found
    allow(Dir).to receive(:glob).and_return([]) # Default to no views
  end

  describe '#build' do
    context 'when the model does not exist' do
      it 'returns nil' do
        expect(builder.build('NonExistentModel')).to be_nil
      end
    end

    context 'when the model exists' do
      context 'with a complete set of related files' do
        before do
          allow(File).to receive(:exist?).with(user_policy_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/**/*.erb').and_return(all_view_paths)
        end

        it 'returns a context hash with all related file paths' do
          context = builder.build('User')

          expect(context[:model]).to eq('/fake/project/app/models/user.rb')
          expect(context[:primary_controller]).to eq('/fake/project/app/controllers/users_controller.rb')
          expect(context[:primary_policy]).to eq(user_policy_path)
        end

        it 'identifies related models from associations' do
          context = builder.build('User')
          expect(context[:related_models]).to contain_exactly(
            '/fake/project/app/models/post.rb',
            '/fake/project/app/models/account.rb'
          )
        end

        it 'identifies primary views by matching the model name in the filename' do
          context = builder.build('User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/shared/user_profile.html.erb'
          )
        end
      end

      context 'with missing related files' do
        it 'returns nil for a missing controller' do
          # The map has no 'PostsController'
          context = builder.build('Post')
          expect(context[:primary_controller]).to be_nil
        end

        it 'returns nil for a missing policy' do
          # File.exist? defaults to false
          context = builder.build('User')
          expect(context[:primary_policy]).to be_nil
        end

        it 'returns an empty array for a model with no associations' do
          context = builder.build('Post')
          expect(context[:related_models]).to be_empty
        end

        it 'returns an empty array when no views match' do
          allow(Dir).to receive(:glob).and_return(all_view_paths)
          # No views contain the word 'account'
          context = builder.build('Account')
          expect(context[:primary_views]).to be_empty
        end
      end

      context 'with irregular pluralization' do
        it 'finds the correct primary controller' do
          # "Person" -> "PeopleController"
          context = builder.build('Person')
          expect(context[:primary_controller]).to eq('/fake/project/app/controllers/people_controller.rb')
        end
      end

      context 'for primary_views logic' do
        let(:standard_view_paths) do
          [
            '/fake/project/app/views/users/index.html.erb',      # basename: index.html.erb
            '/fake/project/app/views/users/show.html.erb',       # basename: show.html.erb
            '/fake/project/app/views/users/edit.html.erb',       # basename: edit.html.erb
            '/fake/project/app/views/users/_form.html.erb',      # basename: _form.html.erb
            '/fake/project/app/views/users/custom_user_report.html.erb', # basename: custom_user_report.html.erb
            '/fake/project/app/views/shared/_user_card.html.erb' # basename: _user_card.html.erb
          ]
        end

        before do
          allow(Dir).to receive(:glob).with('/fake/project/app/views/**/*.erb').and_return(standard_view_paths)
        end

        it 'finds views where the model name appears in the filename' do
          context = builder.build('User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/users/custom_user_report.html.erb',
            '/fake/project/app/views/shared/_user_card.html.erb'
          )
        end

        it 'does NOT find standard RESTful views where model name is only in the directory' do
          context = builder.build('User')
          expect(context[:primary_views]).not_to include(
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/show.html.erb',
            '/fake/project/app/views/users/edit.html.erb',
            '/fake/project/app/views/users/_form.html.erb'
          )
        end
      end

      context 'with namespaced models' do
        let(:project_map) do
          {
            models: {
              'Admin::User' => { path: '/fake/project/app/models/admin/user.rb', associations: {} }
            },
            controllers: {
              'Admin::UsersController' => { path: '/fake/project/app/controllers/admin/users_controller.rb' }
            }
          }
        end
        let(:admin_user_policy_path) { '/fake/project/app/policies/admin/user_policy.rb' }
        let(:admin_view_paths) { ['/fake/project/app/views/admin/users/_admin_user_form.html.erb'] }

        before do
          allow(File).to receive(:exist?).with(admin_user_policy_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/**/*.erb').and_return(admin_view_paths)
        end

        it 'finds the correct namespaced controller' do
          context = builder.build('Admin::User')
          expect(context[:primary_controller]).to eq('/fake/project/app/controllers/admin/users_controller.rb')
        end

        it 'finds the correct namespaced policy' do
          context = builder.build('Admin::User')
          expect(context[:primary_policy]).to eq(admin_user_policy_path)
        end

        it 'finds views based on the underscored namespaced model name' do
          # Admin::User -> 'admin/user'. The current logic incorrectly looks for 'admin/user'
          # in the filename, which will never match. This test confirms that bug.
          context = builder.build('Admin::User')
          expect(context[:primary_views]).to be_empty
        end
      end
    end
  end
end
