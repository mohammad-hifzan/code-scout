require 'spec_helper'
require 'fileutils'
require 'tmpdir'

require_relative '../../lib/analysis/controller_analyzer'

RSpec.describe ControllerAnalyzer do
  subject(:analyzer) { described_class.new }

  let!(:project_path) { Dir.mktmpdir }
  after { FileUtils.remove_entry(project_path) }

  def create_controller_file(name, content)
    full_path = File.join(project_path, "#{name}.rb")
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  describe '#analyze' do
    context 'with an empty controller file' do
      let(:path) { create_controller_file('empty_controller', '') }

      it 'returns a structure with empty values' do
        result = analyzer.analyze(path)
        expect(result[:controller]).to eq('empty_controller')
        expect(result[:modules]).to be_empty
        expect(result[:callbacks]).to eq({ before: [], after: [], around: [] })
        expect(result[:actions]).to be_empty
      end
    end

    context 'controller identity' do
      it 'derives the controller name from the path' do
        path = create_controller_file('posts_controller', 'class PostsController; end')
        result = analyzer.analyze(path)
        expect(result[:controller]).to eq('posts_controller')
      end

      it 'handles namespaced controller names' do
        path = create_controller_file('api/v1/users_controller', 'class Api::V1::UsersController; end')
        result = analyzer.analyze(path)
        expect(result[:controller]).to eq('users_controller')
      end
    end

    context 'included modules' do
      let(:content) do
        <<~RUBY
          class PostsController < ApplicationController
            include Pagination
            include Namespace::Concerns::Filterable # namespaced

            # Should not match
            # include MyModule
            def index
              # code
            end
          end
        RUBY
      end
      let(:path) { create_controller_file('posts_controller', content) }

      it 'extracts top-level included modules' do
        result = analyzer.analyze(path)
        expect(result[:modules]).to contain_exactly('Pagination', 'Namespace::Concerns::Filterable')
      end
    end

    context 'callbacks' do
      let(:content) do
        <<~RUBY
          class PostsController < ApplicationController
            before_action :find_post, only: [:show, :edit]
            after_action :track_view
            around_action :time_request
            before_action :set_user, except: [:index]
            before_action "some_method"
          end
        RUBY
      end
      let(:path) { create_controller_file('posts_controller', content) }

      it 'extracts all supported callback types' do
        callbacks = analyzer.analyze(path)[:callbacks]
        expect(callbacks[:before]).to contain_exactly('find_post', 'set_user', 'some_method')
        expect(callbacks[:after]).to contain_exactly('track_view')
        expect(callbacks[:around]).to contain_exactly('time_request')
      end
    end

    context 'actions' do
      let(:content) do
        <<~RUBY
          class PostsController < ApplicationController
            # Public action
            def index
            end

            # Public action with a bang
            def create!
            end

            private

            # A true private method
            def private_helper
            end

            protected

            # A protected method
            def protected_helper
            end
          end
        RUBY
      end
      let(:path) { create_controller_file('posts_controller', content) }

      it 'extracts only public action methods' do
        action_names = analyzer.analyze(path)[:actions].map { |a| a[:name] }
        expect(action_names).to contain_exactly('index', 'create!')
      end

      it 'ignores private and protected methods' do
        action_names = analyzer.analyze(path)[:actions].map { |a| a[:name] }
        expect(action_names).not_to include('private_helper')
        expect(action_names).not_to include('protected_helper')
      end
      
      context 'with a controller with no public actions' do
        let(:content) do
          <<~RUBY
            class InternalController < ApplicationController
              private
              def do_stuff
              end
            end
          RUBY
        end
        let(:path) { create_controller_file('internal_controller', content) }

        it 'returns an empty actions array' do
          actions = analyzer.analyze(path)[:actions]
          expect(actions).to be_empty
        end
      end
    end

    context 'action analysis (authorize and models)' do
      let(:content) do
        <<~RUBY
          class PostsController < ApplicationController
            def show
              @post = Post.find(params[:id])
              authorize @post
            end

            def new
              @post = Post.new
              @shop = Shop.find_by(id: params[:shop_id])
            end

            def create
              # Model usage
              @post = Current.user.posts.create!(post_params)
              Comment.create(post: @post, body: "First!")
              Api::V1::Notification.new.notify

              # Inferred model usage
              @user = User.find(1)
            end

            def destroy
              # No authorize call
              post = Post.find(params[:id])
              post.destroy
            end

            private

            def post_params
              params.require(:post).permit(:title, :body)
            end
          end
        RUBY
      end
      let(:path) { create_controller_file('posts_controller', content) }

      it 'correctly identifies actions that call `authorize`' do
        actions = analyzer.analyze(path)[:actions]
        show_action = actions.find { |a| a[:name] == 'show' }
        destroy_action = actions.find { |a| a[:name] == 'destroy' }

        expect(show_action[:authorizes]).to be true
        expect(destroy_action[:authorizes]).to be false
      end

      it 'extracts models used via common class methods' do
        actions = analyzer.analyze(path)[:actions]
        show_action = actions.find { |a| a[:name] == 'show' }
        new_action = actions.find { |a| a[:name] == 'new' }
        create_action = actions.find { |a| a[:name] == 'create' }
        destroy_action = actions.find { |a| a[:name] == 'destroy' }

        expect(show_action[:models]).to contain_exactly('Post')
        expect(new_action[:models]).to contain_exactly('Post', 'Shop')
        expect(create_action[:models]).to contain_exactly('Comment', 'Api::V1::Notification', 'User', 'Post')
        expect(destroy_action[:models]).to contain_exactly('Post')
      end

      it 'infers models from instance variables' do
        actions = analyzer.analyze(path)[:actions]
        show_action = actions.find { |a| a[:name] == 'show' }
        new_action = actions.find { |a| a[:name] == 'new' }
        
        expect(show_action[:models]).to include('Post')
        expect(new_action[:models]).to include('Post', 'Shop')
      end

      it 'gets a unique list of models' do
        actions = analyzer.analyze(path)[:actions]
        show_action = actions.find { |a| a[:name] == 'show' }

        expect(show_action[:models].count('Post')).to eq(1)
      end
    end
  end
end