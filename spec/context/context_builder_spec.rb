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
        },
        'Admin::User' => {
          path: '/fake/project/app/models/admin/user.rb',
          associations: {}
        }
      },
      controllers: {
        'UsersController' => { path: '/fake/project/app/controllers/users_controller.rb' },
        'PeopleController' => { path: '/fake/project/app/controllers/people_controller.rb' },
        'Admin::UsersController' => { path: '/fake/project/app/controllers/admin/users_controller.rb' }
      }
    }
  end

  let(:user_policy_path) { '/fake/project/app/policies/user_policy.rb' }
  let(:admin_user_policy_path) { '/fake/project/app/policies/admin/user_policy.rb' }

  before do
    # Mock filesystem interactions
    allow(File).to receive(:exist?).and_return(false) # Default to not found
    allow(Dir).to receive(:glob).and_return([]) # Default to no views unless specifically mocked
  end

  describe '#build' do
    context 'when the model does not exist' do
      it 'returns nil' do
        expect(builder.build('NonExistentModel')).to be_nil
      end
    end

    context 'when the model exists' do
      context 'with a complete set of related files' do
        let(:user_views) do
          [
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/_form.html.erb',
            '/fake/project/app/views/users/show.html.erb',
            '/fake/project/app/views/users/new.html.erb'
          ]
        end

        before do
          allow(File).to receive(:exist?).with(user_policy_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/users/**/*.erb').and_return(user_views)
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

        it 'identifies primary views from the model\'s conventional directory' do
          context = builder.build('User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/_form.html.erb',
            '/fake/project/app/views/users/show.html.erb',
            '/fake/project/app/views/users/new.html.erb'
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

        it 'returns an empty array when no views match for the model\'s directory' do
          allow(Dir).to receive(:glob).with('/fake/project/app/views/accounts/**/*.erb').and_return([])
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

      context 'for primary_views logic details' do
        let(:user_directory_views) do
          [
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/custom_report.html.erb',
            '/fake/project/app/views/users/subfolder/_partial.html.erb'
          ]
        end
        let(:shared_views) do
          ['/fake/project/app/views/shared/_user_card.html.erb']
        end

        before do
          allow(Dir).to receive(:glob).with('/fake/project/app/views/users/**/*.erb').and_return(user_directory_views)
          # Ensure globs for other directories (like shared) return nothing if not explicitly mocked
          allow(Dir).to receive(:glob).with('/fake/project/app/views/shared/**/*.erb').and_return(shared_views)
        end

        it 'finds all .erb files within the model\'s conventional view directory' do
          context = builder.build('User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/custom_report.html.erb',
            '/fake/project/app/views/users/subfolder/_partial.html.erb'
          )
        end

        it 'does NOT find views outside the model\'s conventional directory (e.g., shared views)' do
          context = builder.build('User')
          expect(context[:primary_views]).not_to include(
            '/fake/project/app/views/shared/_user_card.html.erb'
          )
        end
      end

      context 'with namespaced models' do
        let(:admin_user_views) do
          [
            '/fake/project/app/views/admin/users/index.html.erb',
            '/fake/project/app/views/admin/users/_form.html.erb'
          ]
        end

        before do
          allow(File).to receive(:exist?).with(admin_user_policy_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/admin/users/**/*.erb').and_return(admin_user_views)
        end

        it 'finds the correct namespaced controller' do
          context = builder.build('Admin::User')
          expect(context[:primary_controller]).to eq('/fake/project/app/controllers/admin/users_controller.rb')
        end

        it 'finds the correct namespaced policy' do
          context = builder.build('Admin::User')
          expect(context[:primary_policy]).to eq(admin_user_policy_path)
        end

        it 'finds views in the namespaced model\'s conventional directory' do
          context = builder.build('Admin::User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/admin/users/index.html.erb',
            '/fake/project/app/views/admin/users/_form.html.erb'
          )
        end
      end
    end
  end

  # Test cases for the private method `related_models`
  describe '#related_models' do
    let(:project_map) do
      {
        models: {
          'User' => {
            path: '/fake/project/app/models/user.rb',
            associations: { has_many: [:posts], belongs_to: [:account] }
          },
          'Post' => { path: '/fake/project/app/models/post.rb', associations: {} },
          'Account' => { path: '/fake/project/app/models/account.rb', associations: {} },
          'Comment' => {
            path: '/fake/project/app/models/comment.rb',
            associations: {
              has_many: [:likes], # 'Like' model does not exist
              belongs_to: [:user],
              has_one: [:attachment]
            }
          },
          'Attachment' => { path: '/fake/project/app/models/attachment.rb', associations: {} },
          'Media' => { path: '/fake/project/app/models/media.rb', associations: {} }, # Irregular plural
          'Content' => {
            path: '/fake/project/app/models/content.rb',
            associations: { has_many: [:media] }
          }
        }
      }
    end

    it 'resolves `has_many` associations to existing models' do
      related = builder.send(:related_models, project_map[:models]['User'])
      expect(related).to include('/fake/project/app/models/post.rb')
    end

    it 'resolves `belongs_to` associations to existing models' do
      related = builder.send(:related_models, project_map[:models]['User'])
      expect(related).to include('/fake/project/app/models/account.rb')
    end

    it 'returns all related model paths from multiple association types' do
      related = builder.send(:related_models, project_map[:models]['Comment'])
      expect(related).to contain_exactly(
        '/fake/project/app/models/user.rb',
        '/fake/project/app/models/attachment.rb'
      )
    end

    it 'ignores associations where the derived model does not exist in the project map' do
      related = builder.send(:related_models, project_map[:models]['Comment'])
      # 'likes' -> 'Like', which is not in the map
      expect(related).not_to include(a_string_ending_with('like.rb'))
    end

    it 'returns an empty array for a model with no associations' do
      related = builder.send(:related_models, project_map[:models]['Post'])
      expect(related).to be_empty
    end

    context 'with structured association metadata' do
      let(:project_map) do
        {
          models: {
            'Order' => {
              path: '/fake/project/app/models/order.rb',
              associations: {
                has_many: [
                  { name: 'items', class_name: 'OrderItem' },
                  { name: 'commenters', through: 'comments', source: 'user' }
                ],
                belongs_to: [
                  { name: 'author', class_name: 'Admin::User' }
                ]
              }
            },
            'OrderItem' => { path: '/fake/project/app/models/order_item.rb', associations: {} },
            'Admin::User' => { path: '/fake/project/app/models/admin/user.rb', associations: {} },
            'User' => { path: '/fake/project/app/models/user.rb', associations: {} }
          }
        }
      end

      it 'resolves explicit class_name targets for has_many and belongs_to' do
        related = builder.send(:related_models, project_map[:models]['Order'])
        expect(related).to include('/fake/project/app/models/order_item.rb')
        expect(related).to include('/fake/project/app/models/admin/user.rb')
      end

      it 'does not treat source option as a direct dependency for through/source associations' do
        related = builder.send(:related_models, project_map[:models]['Order'])
        expect(related).not_to include('/fake/project/app/models/user.rb')
      end

      it 'resolves the intermediate through model as a direct dependency when present' do
        map = {
          models: {
            'Post' => {
              path: '/fake/project/app/models/post.rb',
              associations: {
                has_many: [{ name: 'tags', through: 'taggings' }]
              }
            },
            'Tagging' => { path: '/fake/project/app/models/tagging.rb', associations: {} },
            'Tag' => { path: '/fake/project/app/models/tag.rb', associations: {} }
          }
        }
        test_builder = described_class.new(map, '/fake/project')
        related = test_builder.send(:related_models, map[:models]['Post'])
        expect(related).to contain_exactly('/fake/project/app/models/tagging.rb')
      end

      context 'with namespaced model resolving relative association' do
        let(:project_map) do
          {
            models: {
              'Billing::Invoice' => {
                path: '/fake/project/app/models/billing/invoice.rb',
                associations: {
                  belongs_to: [{ name: 'customer' }]
                }
              },
              'Billing::Customer' => {
                path: '/fake/project/app/models/billing/customer.rb',
                associations: {}
              }
            },
            controllers: {}
          }
        end

        it 'resolves the association relative to the model namespace' do
          context = builder.build('Billing::Invoice')
          expect(context[:related_models]).to contain_exactly(
            '/fake/project/app/models/billing/customer.rb'
          )
        end
      end
    end

    context 'with polymorphic associations' do
      let(:project_map) do
        {
          models: {
            'Picture' => {
              path: '/fake/project/app/models/picture.rb',
              associations: {
                belongs_to: [{ name: 'imageable', polymorphic: true }]
              }
            },
            'Post' => {
              path: '/fake/project/app/models/post.rb',
              associations: {
                has_many: [{ name: 'pictures', as: 'imageable' }]
              }
            },
            'MixedModel' => {
              path: '/fake/project/app/models/mixed_model.rb',
              associations: {
                belongs_to: [{ name: 'imageable', polymorphic: true }],
                has_many: [{ name: 'posts' }]
              }
            },
            'Imageable' => {
              path: '/fake/project/app/models/imageable.rb',
              associations: {}
            }
          },
          controllers: {}
        }
      end

      it 'does not treat polymorphic belongs_to interface as a related model' do
        context = builder.build('Picture')
        expect(context[:related_models]).to be_empty
        expect(context[:related_models]).not_to include('/fake/project/app/models/imageable.rb')
      end

      it 'does not resolve to Imageable model even when Imageable exists in the project map' do
        related = builder.send(:related_models, project_map[:models]['Picture'], 'Picture')
        expect(related).to be_empty
      end

      it 'resolves the target model for has_many with as: option normally' do
        context = builder.build('Post')
        expect(context[:related_models]).to contain_exactly('/fake/project/app/models/picture.rb')
      end

      it 'resolves concrete associations while ignoring polymorphic ones in mixed models' do
        context = builder.build('MixedModel')
        expect(context[:related_models]).to contain_exactly('/fake/project/app/models/post.rb')
      end
    end

    context 'with irregular plurals' do
      it 'fails to find the model if the singularization is incorrect' do
        # The current implementation does: :media -> "media" -> singularize -> "medium" -> camelize -> "Medium"
        # It looks for a "Medium" model, which does not exist in our map.
        # This test confirms that it does NOT find the "Media" model.
        related = builder.send(:related_models, project_map[:models]['Content'])
        expect(related).to be_empty
        expect(related).not_to include('/fake/project/app/models/media.rb')
      end
    end
  end
end
