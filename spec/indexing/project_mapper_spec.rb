require "spec_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/indexing/project_mapper"

RSpec.describe ProjectMapper do
  subject(:mapper) { described_class.new(project_path) }

  let!(:project_path) { Dir.mktmpdir }
  after { FileUtils.remove_entry(project_path) }

  def create_file(relative_path, content = "")
    full_path = File.join(project_path, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  describe "#map" do
    context "when scanning an empty project" do
      it "returns a map with empty values" do
        expect(mapper.map).to eq({models: {}, controllers: {}, views: {}})
      end

      it "returns an empty map when app directories are present but empty" do
        FileUtils.mkdir_p(File.join(project_path, "app", "models"))
        FileUtils.mkdir_p(File.join(project_path, "app", "controllers"))
        FileUtils.mkdir_p(File.join(project_path, "app", "views"))
        expect(mapper.map).to eq({models: {}, controllers: {}, views: {}})
      end
    end

    context "when scanning for models" do
      before { FileUtils.mkdir_p(File.join(project_path, "app", "models")) }

      context "with a typical model" do
        let!(:model_path) do
          create_file "app/models/user.rb", <<~RUBY
            class User < ApplicationRecord
              has_many :posts
              belongs_to :account
              has_one :profile, dependent: :destroy
            end
          RUBY
        end

        it "identifies the model's path and class name" do
          expect(mapper.map[:models]).to have_key("User")
          expect(mapper.map[:models]["User"][:path]).to eq(model_path)
        end

        it "extracts all association types correctly" do
          associations = mapper.map[:models]["User"][:associations]
          expect(associations[:has_many]).to eq([{ name: "posts" }])
          expect(associations[:belongs_to]).to eq([{ name: "account" }])
          expect(associations[:has_one]).to eq([{ name: "profile" }])
        end
      end

      context "with a model that has no associations" do
        before { create_file "app/models/post.rb", "class Post < ApplicationRecord; end" }

        it "identifies the model with an empty associations hash" do
          associations = mapper.map[:models]["Post"][:associations]
          expect(associations).to eq({belongs_to: [], has_many: [], has_one: []})
        end
      end

      context "with an empty model file" do
        before { create_file "app/models/comment.rb", "" }

        it "identifies the model with an empty associations hash" do
          associations = mapper.map[:models]["Comment"][:associations]
          expect(associations).to eq({belongs_to: [], has_many: [], has_one: []})
        end
      end

      context "with complex association syntax" do
        before do
          create_file "app/models/team.rb", <<~RUBY
            class Team < ApplicationRecord
              has_many :memberships,
                       dependent: :destroy
            end
          RUBY
        end

        it "correctly matches the association" do
          associations = mapper.map[:models]["Team"][:associations]
          expect(associations[:has_many]).to eq([{ name: "memberships" }])
        end
      end

      context "with associations having options (class_name, through, source)" do
        before do
          create_file "app/models/post.rb", <<~RUBY
            class Post < ApplicationRecord
              has_many :items, class_name: "OrderItem"
              has_many :commenters, through: :comments, source: :user
              belongs_to :author, class_name: "User"
              has_one :profile, class_name: "UserProfile", through: :account
            end
          RUBY
        end

        it "preserves structured association metadata" do
          associations = mapper.map[:models]["Post"][:associations]
          expect(associations[:has_many]).to include(
            { name: "items", class_name: "OrderItem" },
            { name: "commenters", through: "comments", source: "user" }
          )
          expect(associations[:belongs_to]).to include(
            { name: "author", class_name: "User" }
          )
          expect(associations[:has_one]).to include(
            { name: "profile", class_name: "UserProfile", through: "account" }
          )
        end
      end

      context "with an ApplicationRecord model" do
        before { create_file "app/models/application_record.rb" }

        it "ignores ApplicationRecord and does not include it in the map" do
          expect(mapper.map[:models]).not_to have_key("ApplicationRecord")
        end
      end

      context "with a namespaced model" do
        let!(:namespaced_model_path) do
          create_file "app/models/billing/invoice.rb", <<~RUBY
            class Billing::Invoice < ApplicationRecord
              belongs_to :customer
            end
          RUBY
        end

        it "identifies the namespaced model's path and class name" do
          models = mapper.map[:models]
          expect(models).to have_key("Billing::Invoice")
          expect(models["Billing::Invoice"][:path]).to eq(namespaced_model_path)
        end

        it "extracts associations from the namespaced model" do
          associations = mapper.map[:models]["Billing::Invoice"][:associations]
          expect(associations[:belongs_to]).to eq([{ name: "customer" }])
        end
      end
    end

    context "when scanning for controllers" do
      before { FileUtils.mkdir_p(File.join(project_path, "app", "controllers")) }

      context "with controllers at the root and in subdirectories" do
        let!(:posts_controller_path) { create_file "app/controllers/posts_controller.rb" }
        let!(:api_users_controller_path) { create_file "app/controllers/api/v1/users_controller.rb" }

        it "identifies all controllers and their correct paths" do
          controllers = mapper.map[:controllers]
          expect(controllers).to have_key("PostsController")
          expect(controllers["PostsController"][:path]).to eq(posts_controller_path)
          expect(controllers).to have_key("Api::V1::UsersController")
          expect(controllers["Api::V1::UsersController"][:path]).to eq(api_users_controller_path)
        end
      end

      context "with an ApplicationController" do
        before { create_file "app/controllers/application_controller.rb" }

        it "ignores ApplicationController and does not include it in the map" do
          expect(mapper.map[:controllers]).not_to have_key("ApplicationController")
        end
      end
    end

    context "when scanning for views" do
      before { FileUtils.mkdir_p(File.join(project_path, "app", "views")) }

      context "with standard view structures" do
        let!(:index_path) { create_file "app/views/posts/index.html.erb" }
        let!(:show_path) { create_file "app/views/posts/show.html.erb" }
        let!(:partial_path) { create_file "app/views/posts/shared/_form.html.erb" }

        it "maps folder names to a list of their template file paths" do
          views = mapper.map[:views]
          expect(views).to have_key("posts")
          expect(views["posts"]).to contain_exactly(index_path, show_path, partial_path)
        end
      end

      context "with an empty view folder" do
        before { FileUtils.mkdir_p(File.join(project_path, "app", "views", "users")) }

        it "maps the folder name to an empty array" do
          expect(mapper.map[:views]["users"]).to be_empty
        end
      end

      context "with template files directly in the app/views root" do
        before { create_file "app/views/ignored.html.erb" }

        it "ignores files that are not in a subdirectory" do
          expect(mapper.map[:views]).to be_empty
        end
      end
    end

    context "when scanning a full project" do
      let!(:user_model_path) { create_file "app/models/user.rb", "class User < ApplicationRecord; has_many :posts; end" }
      let!(:post_model_path) { create_file "app/models/post.rb", "class Post < ApplicationRecord; belongs_to :user; end" }
      let!(:users_controller_path) { create_file "app/controllers/users_controller.rb" }
      let!(:posts_view_path) { create_file "app/views/posts/index.html.erb" }

      it "produces a complete and accurate map of all components" do
        result = mapper.map

        # Verify models
        expect(result[:models].keys).to contain_exactly("User", "Post")
        expect(result[:models]["User"][:path]).to eq(user_model_path)
        expect(result[:models]["User"][:associations][:has_many]).to eq([{ name: "posts" }])
        expect(result[:models]["Post"][:associations][:belongs_to]).to eq([{ name: "user" }])

        # Verify controllers
        expect(result[:controllers].keys).to contain_exactly("UsersController")
        expect(result[:controllers]["UsersController"][:path]).to eq(users_controller_path)

        # Verify views
        expect(result[:views].keys).to contain_exactly("posts")
        expect(result[:views]["posts"]).to contain_exactly(posts_view_path)
      end
    end
  end
end
