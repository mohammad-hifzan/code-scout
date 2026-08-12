require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require_relative '../../lib/analysis/inspector'

RSpec.describe Inspector do
  let(:project_path) { @project_path }
  let(:inspector) { described_class.new(project_map, project_path) }

  around do |example|
    Dir.mktmpdir do |dir|
      @project_path = dir
      example.run
    end
  end

  def create_file(path, content)
    full_path = File.join(project_path, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  describe '#inspect_model' do
    context 'with a non-existent model' do
      let(:project_map) { { models: {} } }

      it 'returns nil' do
        expect(inspector.inspect_model('NonExistentModel')).to be_nil
      end
    end

    context 'with a model that does not exist in the project map but has files referencing it' do
      let(:project_map) { { models: {} } }

      before do
        create_file('app/controllers/users_controller.rb', 'class UsersController; end')
      end

      it 'returns nil because the model is not in the map' do
        expect(inspector.inspect_model('User')).to be_nil
      end
    end

    context 'with an empty project map' do
      let(:project_map) { {} }
      it 'handles it gracefully without crashing' do
        expect { inspector.inspect_model('AnyModel') }.not_to raise_error
      end

      it 'returns nil' do
        expect(inspector.inspect_model('AnyModel')).to be_nil
      end
    end

    context 'with a basic model and its controller' do
      let(:project_map) do
        {
          models: {
            'User' => {
              path: 'app/models/user.rb',
              associations: { 'has_many' => ['posts'] }
            }
          }
        }
      end

      before do
        create_file('app/models/user.rb', 'class User < ApplicationRecord; has_many :posts; end')
        create_file('app/controllers/users_controller.rb', 'class UsersController < ApplicationController; def index; @users = User.all; end; end')
        create_file('app/views/users/index.html.erb', '<h1>People</h1>')
      end

      it 'returns the model information' do
        result = inspector.inspect_model('User')
        expect(result[:path]).to eq('app/models/user.rb')
      end

      it 'returns the model associations' do
        result = inspector.inspect_model('User')
        expect(result[:associations]).to eq({ 'has_many' => ['posts'] })
      end

      it 'finds and categorizes references' do
        result = inspector.inspect_model('User')
        expect(result[:references][:models]).to include(a_string_ending_with('app/models/user.rb'))
        expect(result[:references][:controllers]).to include(a_string_ending_with('app/controllers/users_controller.rb'))
      end

      it 'ranks references' do
        result = inspector.inspect_model('User')
        expect(result[:ranked_references][:primary]).to include(a_string_ending_with('app/models/user.rb'))
        expect(result[:ranked_references][:primary]).to include(a_string_ending_with('app/controllers/users_controller.rb'))
      end

      it 'does not find references in files that do not contain the model name' do
        result = inspector.inspect_model('User')
        expect(result[:references][:views]).to be_empty
      end
    end

    context 'when dealing with namespaced models' do
      let(:project_map) do
        {
          models: {
            'Admin::User' => {
              path: 'app/models/admin/user.rb',
              associations: {}
            }
          }
        }
      end

      before do
        create_file('app/models/admin/user.rb', 'class Admin::User < ApplicationRecord; end')
        create_file('app/controllers/admin/users_controller.rb', 'class Admin::UsersController < ApplicationController; def show; @user = Admin::User.find(params[:id]); end; end')
        # This file references 'user' but not 'Admin::User'
        create_file('app/models/post.rb', 'class Post < ApplicationRecord; belongs_to :user; end')
      end

      it 'finds references to the namespaced model' do
        result = inspector.inspect_model('Admin::User')
        expect(result[:references][:models]).to include(a_string_ending_with('app/models/admin/user.rb'))
        expect(result[:references][:controllers]).to include(a_string_ending_with('app/controllers/admin/users_controller.rb'))
      end

      it 'does not include references to other models with similar names' do
        result = inspector.inspect_model('Admin::User')
        # The string "user" is in post.rb, but "Admin::User" is not, nor is 'admin/user'.
        # The current naive string search in ReferenceFinder will not find this.
        expect(result[:references][:models]).not_to include(a_string_ending_with('app/models/post.rb'))
      end
    end

    context 'when a reference is only a substring of another constant name' do
      let(:project_map) do
        {
          models: {
            'User' => {
              path: 'app/models/user.rb',
              associations: {}
            }
          }
        }
      end

      before do
        create_file('app/models/user.rb', 'class User; end')
        create_file('app/services/abuser_reporter.rb', 'class AbuserReporter; end')
        create_file('app/models/user_profile.rb', 'class UserProfile; end')
      end

      it 'does not treat substrings as references' do
        result = inspector.inspect_model('User')
        expect(result[:references][:services]).not_to include(a_string_ending_with('app/services/abuser_reporter.rb'))
        expect(result[:references][:models]).not_to include(a_string_ending_with('app/models/user_profile.rb'))
      end
    end

    context 'with multiple and duplicate references' do
      let(:project_map) do
        {
          models: {
            'Post' => {
              path: 'app/models/post.rb',
              associations: {}
            }
          }
        }
      end

      before do
        create_file('app/models/post.rb', 'class Post; end')
        create_file('app/controllers/posts_controller.rb', 'class PostsController; Post.all; Post.first; end')
        create_file('app/jobs/post_notification_job.rb', 'class PostNotificationJob; def perform(post); end; end')
      end

      it 'categorizes each file only once' do
        result = inspector.inspect_model('Post')
        expect(result[:references][:controllers].count).to eq(1)
        expect(result[:references][:controllers].first).to end_with('app/controllers/posts_controller.rb')
      end

      it 'ranks each file only once and ignores false positives' do
        result = inspector.inspect_model('Post')
        expect(result[:ranked_references][:primary].count).to eq(2) # model and controller
        expect(result[:ranked_references][:primary]).to include(a_string_ending_with('app/controllers/posts_controller.rb'))
        expect(result[:ranked_references][:tertiary]).to be_empty
      end
    end

    context 'with a model with no references' do
      let(:project_map) do
        {
          models: {
            'Orphan' => {
              path: 'app/models/orphan.rb',
              associations: {}
            }
          }
        }
      end

      before do
        create_file('app/models/orphan.rb', 'class Orphan; end')
        create_file('app/models/unrelated.rb', 'class Unrelated; end')
      end

      it 'only finds a reference to itself' do
        result = inspector.inspect_model('Orphan')
        # It will always find itself
        expect(result[:references].values.flatten.count).to eq(1)
        expect(result[:references][:models].first).to end_with('app/models/orphan.rb')
      end
    end

    context 'with a model with no associations' do
      let(:project_map) do
        {
          models: {
            'Post' => {
              path: 'app/models/post.rb',
              associations: {}
            }
          }
        }
      end

      before do
        create_file('app/models/post.rb', 'class Post; end')
      end

      it 'returns an empty association hash' do
        result = inspector.inspect_model('Post')
        expect(result[:associations]).to eq({})
      end
    end
  end
end
