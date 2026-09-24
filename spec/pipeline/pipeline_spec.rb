require "spec_helper"

require_relative "../../lib/pipeline/pipeline"
require_relative "../../lib/nlp/request_analyzer"
require_relative "../../lib/nlp/rule_selector"

require_relative "../../lib/indexing/project_mapper"
require_relative "../../lib/indexing/project_index"

require_relative "../../lib/context/context_engine"
require_relative "../../lib/context/token_estimator"
require_relative "../../lib/context/context_pruner"
require_relative "../../lib/context/file_loader"

require_relative "../../lib/prompts/prompt_builder"

RSpec.describe Pipeline::Pipeline do
  let(:project_path) { "/tmp/shop" }
  let(:request) { "Add slug validation to Shop" }

  let(:analysis) do
    {
      action: :edit,
      entity: "Shop"
    }
  end

  let(:rule) { double("EditRule") }

  let(:project_map) { {} }

  let(:project_index) { double(ProjectIndex) }

  let(:context) do
    {
      ranked: [
        {
          path: "app/models/shop.rb",
          score: 100
        }
      ]
    }
  end

  let(:estimated) do
    {
      files: [
        {
          path: "app/models/shop.rb",
          estimated_tokens: 120
        }
      ]
    }
  end

  let(:pruned) do
    {
      files: [
        {
          path: "app/models/shop.rb",
          estimated_tokens: 120
        }
      ]
    }
  end

  let(:loaded_files) do
    [
      {
        path: "app/models/shop.rb",
        content: "class Shop < ApplicationRecord\nend"
      }
    ]
  end

  let(:prompt) { "FINAL PROMPT" }

  it "orchestrates the complete request pipeline" do
    analyzer = instance_double(RequestAnalyzer)
    selector = instance_double(RuleSelector)
    mapper = instance_double(ProjectMapper)
    engine = instance_double(ContextEngine)
    estimator = instance_double(TokenEstimator)
    pruner = instance_double(ContextPruner)
    loader = instance_double(FileLoader)
    builder = instance_double(PromptBuilder)

    allow(RequestAnalyzer).to receive(:new).and_return(analyzer)
    allow(RuleSelector).to receive(:new).and_return(selector)
    allow(ProjectMapper).to receive(:new).with(project_path).and_return(mapper)

    allow(ProjectIndex).to receive(:new)
      .with(project_map, project_path)
      .and_return(project_index)

    allow(ContextEngine).to receive(:new)
      .with(project_index)
      .and_return(engine)

    allow(TokenEstimator).to receive(:new).and_return(estimator)
    allow(ContextPruner).to receive(:new).and_return(pruner)
    allow(FileLoader).to receive(:new).and_return(loader)
    allow(PromptBuilder).to receive(:new).and_return(builder)

    expect(analyzer)
      .to receive(:analyze)
      .with(request)
      .and_return(analysis)

    expect(selector)
      .to receive(:select)
      .with(:edit)
      .and_return(rule)

    expect(mapper)
      .to receive(:map)
      .and_return(project_map)

    expect(engine)
      .to receive(:build)
      .with("Shop", rule: rule, topic: :general)
      .and_return(context)

    expect(estimator)
      .to receive(:estimate)
      .with(context[:ranked])
      .and_return(estimated)

    expect(pruner)
      .to receive(:prune)
      .with(estimated, max_tokens: 3000)
      .and_return(pruned)

    expect(loader)
      .to receive(:load_files)
      .with(pruned[:files])
      .and_return(loaded_files)

    expect(builder)
      .to receive(:build)
      .with(
        request: request,
        files: loaded_files
      )
      .and_return(prompt)

    result = described_class.new(project_path).run(request)

    expect(result).to eq(prompt)
  end

  it "fails closed and returns nil when entity cannot be resolved" do
    analyzer = instance_double(RequestAnalyzer)
    selector = instance_double(RuleSelector)
    mapper = instance_double(ProjectMapper)
    engine = instance_double(ContextEngine)

    allow(RequestAnalyzer).to receive(:new).and_return(analyzer)
    allow(RuleSelector).to receive(:new).and_return(selector)
    allow(ProjectMapper).to receive(:new).with(project_path).and_return(mapper)
    allow(ProjectIndex).to receive(:new).and_return(project_index)
    allow(ContextEngine).to receive(:new).and_return(engine)

    expect(mapper).to receive(:map).and_return(project_map)
    expect(analyzer).to receive(:analyze).with(request).and_return({ action: :edit, entity: nil, topic: :general })
    expect(selector).to receive(:select).with(:edit).and_return(rule)
    expect(engine).to receive(:build).with(nil, rule: rule, topic: :general).and_return(nil)

    result = described_class.new(project_path).run(request)
    expect(result).to be_nil
  end

  describe "end-to-end unmocked integration" do
    let!(:tmp_project_path) { Dir.mktmpdir }
    after { FileUtils.remove_entry(tmp_project_path) }

    def create_model_file(name, content)
      full_path = File.join(tmp_project_path, "app", "models", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_controller_file(name, content)
      full_path = File.join(tmp_project_path, "app", "controllers", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_serializer_file(name, content)
      full_path = File.join(tmp_project_path, "app", "serializers", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_policy_file(name, content)
      full_path = File.join(tmp_project_path, "app", "policies", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_job_file(name, content)
      full_path = File.join(tmp_project_path, "app", "jobs", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_worker_file(name, content)
      full_path = File.join(tmp_project_path, "app", "workers", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_mailer_file(name, content)
      full_path = File.join(tmp_project_path, "app", "mailers", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_mailer_view_file(relative_path, content)
      full_path = File.join(tmp_project_path, "app", "views", relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_presenter_file(name, content)
      full_path = File.join(tmp_project_path, "app", "presenters", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_model_concern_file(name, content)
      full_path = File.join(tmp_project_path, "app", "models", "concerns", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_controller_concern_file(name, content)
      full_path = File.join(tmp_project_path, "app", "controllers", "concerns", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_validator_file(name, content)
      full_path = File.join(tmp_project_path, "app", "validators", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    def create_service_file(name, content)
      full_path = File.join(tmp_project_path, "app", "services", "#{name}.rb")
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      full_path
    end

    before do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            has_many :posts
          end
        RUBY
      )
      create_model_file(
        "post",
        <<~RUBY
          class Post < ApplicationRecord
            belongs_to :user
          end
        RUBY
      )
      create_controller_file(
        "users_controller",
        <<~RUBY
          class UsersController < ApplicationController
          end
        RUBY
      )
    end

    it "resolves natural-language request to real User model without phantom Add model" do
      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Add a validation to User.")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("class User < ApplicationRecord")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Add a validation to User.")
      expect(prompt).not_to include("Add.rb")
    end

    it "fails closed when request references an unknown model" do
      pipeline = described_class.new(tmp_project_path)
      result = pipeline.run("Add a validation to UnknownModel.")

      expect(result).to be_nil
    end

    it "propagates :serialization topic to discover and include serializers in context" do
      create_serializer_file(
        "user_serializer",
        <<~RUBY
          class UserSerializer < ActiveModel::Serializer
            attributes :id, :name
            has_many :posts
          end
        RUBY
      )
      create_serializer_file(
        "post_serializer",
        <<~RUBY
          class PostSerializer < ActiveModel::Serializer
            attributes :id, :title
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change how User's posts are serialized.")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/serializers/user_serializer.rb")
      expect(prompt).to include("app/serializers/post_serializer.rb")
      expect(prompt).to include("UserSerializer")
      expect(prompt).to include("PostSerializer")
    end

    it "resolves compound artifact constant in pipeline end-to-end" do
      create_serializer_file(
        "user_serializer",
        <<~RUBY
          class UserSerializer < ActiveModel::Serializer
            attributes :id, :email
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change UserSerializer")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/serializers/user_serializer.rb")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change UserSerializer")
    end

    it "does not include serializers when the topic is :validation" do
      create_serializer_file(
        "user_serializer",
        <<~RUBY
          class UserSerializer < ActiveModel::Serializer
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Add a validation to User.")

      expect(prompt).not_to include("app/serializers/user_serializer.rb")
    end

    it "does not include serializers when the request is generic even if serializer exists on disk" do
      create_serializer_file(
        "user_serializer",
        <<~RUBY
          class UserSerializer < ActiveModel::Serializer
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Update User email.")

      expect(prompt).not_to include("app/serializers/user_serializer.rb")
    end

    it "bounds context and preserves high-priority primary model within token budget" do
      create_serializer_file(
        "user_serializer",
        <<~RUBY
          class UserSerializer < ActiveModel::Serializer
          end
        RUBY
      )

      # Create large view file that might exceed budget if unbounded
      large_view_content = "# Large view\n" + ("x" * 20_000)
      full_view_path = File.join(tmp_project_path, "app", "views", "users", "index.html.erb")
      FileUtils.mkdir_p(File.dirname(full_view_path))
      File.write(full_view_path, large_view_content)

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change how User is serialized.")

      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/serializers/user_serializer.rb")
      expect(prompt).not_to include("x" * 20_000)
    end

    it "elevates UserPolicy into required context for policy explain request" do
      create_policy_file(
        "user_policy",
        <<~RUBY
          class UserPolicy < ApplicationPolicy
            def show?
              user.admin?
            end
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Explain User authorization")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("app/policies/user_policy.rb")
      expect(prompt).to include("UserPolicy")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Explain User authorization")
    end

    it "resolves Change UserJob end-to-end and includes job in required context" do
      create_job_file(
        "user_job",
        <<~RUBY
          class UserJob < ApplicationJob
            def perform(user_id)
              User.find(user_id).process!
            end
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change UserJob")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("app/jobs/user_job.rb")
      expect(prompt).to include("UserJob")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change UserJob")
    end

    it "resolves Why is UserWorker failing? end-to-end and includes worker in required context" do
      create_worker_file(
        "user_worker",
        <<~RUBY
          class UserWorker
            include Sidekiq::Worker
            def perform(user_id)
              User.find(user_id).sync!
            end
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Why is UserWorker failing?")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("app/workers/user_worker.rb")
      expect(prompt).to include("UserWorker")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Why is UserWorker failing?")
    end

    it "resolves Change Admin::UserJob end-to-end and includes namespaced job in required context" do
      create_model_file(
        "admin/user",
        <<~RUBY
          module Admin
            class User < ApplicationRecord
            end
          end
        RUBY
      )
      create_controller_file(
        "admin/users_controller",
        <<~RUBY
          module Admin
            class UsersController < ApplicationController
            end
          end
        RUBY
      )
      create_job_file(
        "admin/user_job",
        <<~RUBY
          module Admin
            class UserJob < ApplicationJob
              def perform(user_id)
                Admin::User.find(user_id).audit!
              end
            end
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change Admin::UserJob")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/admin/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/admin/users_controller.rb")
      expect(prompt).to include("app/jobs/admin/user_job.rb")
      expect(prompt).to include("Admin::UserJob")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change Admin::UserJob")
    end

    it "resolves Change Admin::UserWorker end-to-end and isolates from root user artifacts" do
      create_model_file(
        "admin/user",
        <<~RUBY
          module Admin
            class User < ApplicationRecord
            end
          end
        RUBY
      )
      create_controller_file(
        "admin/users_controller",
        <<~RUBY
          module Admin
            class UsersController < ApplicationController
            end
          end
        RUBY
      )
      create_worker_file(
        "admin/user_worker",
        <<~RUBY
          module Admin
            class UserWorker
              include Sidekiq::Worker
              def perform(user_id)
                Admin::User.find(user_id).sync!
              end
            end
          end
        RUBY
      )
      create_job_file("user_job", "class UserJob < ApplicationJob; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change Admin::UserWorker")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/admin/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/admin/users_controller.rb")
      expect(prompt).to include("app/workers/admin/user_worker.rb")
      expect(prompt).to include("Admin::UserWorker")
      expect(prompt).not_to include("app/jobs/user_job.rb")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change Admin::UserWorker")
    end

    it "does not include jobs or workers for generic model requests" do
      create_job_file("user_job", "class UserJob < ApplicationJob; end")
      create_worker_file("user_worker", "class UserWorker; include Sidekiq::Worker; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Add a validation to User.")

      expect(prompt).to be_a(String)
      expect(prompt).not_to include("app/jobs/user_job.rb")
      expect(prompt).not_to include("app/workers/user_worker.rb")
    end

    it "isolates unrelated artifacts and does not pollute job context" do
      create_job_file("user_job", "class UserJob < ApplicationJob; end")
      create_worker_file("user_worker", "class UserWorker; include Sidekiq::Worker; end")
      create_serializer_file("user_serializer", "class UserSerializer; end")
      create_presenter_file("user_presenter", "class UserPresenter; end")
      create_mailer_file("user_mailer", "class UserMailer < ApplicationMailer; end")
      create_job_file("order_job", "class OrderJob < ApplicationJob; end")
      create_worker_file("billing_worker", "class BillingWorker; include Sidekiq::Worker; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change UserJob")

      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/jobs/user_job.rb")
      expect(prompt).to include("app/workers/user_worker.rb")

      # Pollution checks:
      expect(prompt).not_to include("app/serializers/user_serializer.rb")
      expect(prompt).not_to include("app/presenters/user_presenter.rb")
      expect(prompt).not_to include("app/mailers/user_mailer.rb")
      expect(prompt).not_to include("app/jobs/order_job.rb")
      expect(prompt).not_to include("app/workers/billing_worker.rb")
    end

    it "resolves Change UserMailer end-to-end and includes mailer and mailer views in required context" do
      create_mailer_file(
        "user_mailer",
        <<~RUBY
          class UserMailer < ApplicationMailer
            def welcome_email(user_id)
              @user = User.find(user_id)
              mail(to: @user.email, subject: "Welcome")
            end
          end
        RUBY
      )
      create_mailer_view_file("user_mailer/welcome.html.erb", "<h1>Welcome <%= @user.name %></h1>")
      create_mailer_view_file("user_mailer/welcome.text.erb", "Welcome <%= @user.name %>")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change UserMailer")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("app/mailers/user_mailer.rb")
      expect(prompt).to include("app/views/user_mailer/welcome.html.erb")
      expect(prompt).to include("app/views/user_mailer/welcome.text.erb")
      expect(prompt).to include("UserMailer")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change UserMailer")
    end

    it "resolves Why is UserMailer failing? end-to-end and includes mailer in required context" do
      create_mailer_file(
        "user_mailer",
        <<~RUBY
          class UserMailer < ApplicationMailer
            def notify
            end
          end
        RUBY
      )
      create_mailer_view_file("user_mailer/notify.html.erb", "<p>Notification</p>")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Why is UserMailer failing?")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("app/mailers/user_mailer.rb")
      expect(prompt).to include("app/views/user_mailer/notify.html.erb")
      expect(prompt).to include("UserMailer")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Why is UserMailer failing?")
    end

    it "resolves Change Admin::UserMailer end-to-end and isolates from root user mailers" do
      create_model_file(
        "admin/user",
        <<~RUBY
          module Admin
            class User < ApplicationRecord
            end
          end
        RUBY
      )
      create_controller_file(
        "admin/users_controller",
        <<~RUBY
          module Admin
            class UsersController < ApplicationController
            end
          end
        RUBY
      )
      create_mailer_file(
        "admin/user_mailer",
        <<~RUBY
          module Admin
            class UserMailer < ApplicationMailer
              def alert_admin(admin_id)
                mail(to: "admin@example.com", subject: "Alert")
              end
            end
          end
        RUBY
      )
      create_mailer_view_file("admin/user_mailer/alert.html.erb", "<h1>Admin Alert</h1>")
      create_mailer_file("user_mailer", "class UserMailer < ApplicationMailer; end")
      create_mailer_view_file("user_mailer/welcome.html.erb", "<h1>Welcome</h1>")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change Admin::UserMailer")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/admin/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/admin/users_controller.rb")
      expect(prompt).to include("app/mailers/admin/user_mailer.rb")
      expect(prompt).to include("app/views/admin/user_mailer/alert.html.erb")
      expect(prompt).to include("Admin::UserMailer")
      expect(prompt).not_to include("app/mailers/user_mailer.rb")
      expect(prompt).not_to include("app/views/user_mailer/welcome.html.erb")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change Admin::UserMailer")
    end

    it "does not include mailers or mailer views for generic or non-mailer requests" do
      create_mailer_file("user_mailer", "class UserMailer < ApplicationMailer; end")
      create_mailer_view_file("user_mailer/welcome.html.erb", "<h1>Welcome</h1>")

      pipeline = described_class.new(tmp_project_path)

      ["Update User's email address", "Change User email preferences", "Add email uniqueness validation to User."].each do |req|
        prompt = pipeline.run(req)
        expect(prompt).to be_a(String)
        expect(prompt).not_to include("app/mailers/user_mailer.rb")
        expect(prompt).not_to include("app/views/user_mailer/welcome.html.erb")
      end
    end

    it "isolates unrelated artifacts and does not pollute mailer context" do
      create_mailer_file("user_mailer", "class UserMailer < ApplicationMailer; end")
      create_mailer_view_file("user_mailer/welcome.html.erb", "<h1>Welcome</h1>")
      create_mailer_file("order_mailer", "class OrderMailer < ApplicationMailer; end")
      create_mailer_file("billing_mailer", "class BillingMailer < ApplicationMailer; end")
      create_serializer_file("user_serializer", "class UserSerializer; end")
      create_presenter_file("user_presenter", "class UserPresenter; end")
      create_job_file("user_job", "class UserJob < ApplicationJob; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change UserMailer")

      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/mailers/user_mailer.rb")
      expect(prompt).to include("app/views/user_mailer/welcome.html.erb")

      # Pollution checks:
      expect(prompt).not_to include("app/mailers/order_mailer.rb")
      expect(prompt).not_to include("app/mailers/billing_mailer.rb")
      expect(prompt).not_to include("app/serializers/user_serializer.rb")
      expect(prompt).not_to include("app/presenters/user_presenter.rb")
      expect(prompt).not_to include("app/jobs/user_job.rb")
    end

    it "resolves Change the User model concern end-to-end and includes concern in required context" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            include Auditable
          end
        RUBY
      )
      create_model_concern_file(
        "auditable",
        <<~RUBY
          module Auditable
            extend ActiveSupport::Concern
            included do
              before_save :audit_changes
            end
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change the User model concern")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("app/models/concerns/auditable.rb")
      expect(prompt).to include("Auditable")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change the User model concern")
    end

    it "resolves Why is the Auditable concern failing? end-to-end and includes concern context" do
      create_model_concern_file(
        "auditable",
        <<~RUBY
          module Auditable
            extend ActiveSupport::Concern
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Why is the Auditable concern failing?")

      expect(prompt).to be_a(String)
      expect(prompt).to include("app/models/concerns/auditable.rb")
      expect(prompt).to include("Auditable")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Why is the Auditable concern failing?")
    end

    it "resolves Update the User concern end-to-end and includes concern in required context" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            include Auditable
          end
        RUBY
      )
      create_model_concern_file(
        "auditable",
        <<~RUBY
          module Auditable
            extend ActiveSupport::Concern
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Update the User concern")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/controllers/users_controller.rb")
      expect(prompt).to include("app/models/concerns/auditable.rb")
      expect(prompt).to include("Auditable")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Update the User concern")
    end

    it "does not include model concerns for non-concern requests" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            include Auditable
          end
        RUBY
      )
      create_model_concern_file("auditable", "module Auditable; end")

      pipeline = described_class.new(tmp_project_path)

      ["Add a validation to User", "Update User's email address", "Include User in the response"].each do |req|
        prompt = pipeline.run(req)
        expect(prompt).to be_a(String)
        expect(prompt).not_to include("app/models/concerns/auditable.rb")
      end
    end

    it "isolates unrelated artifacts and controller concerns from model concern context" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            include Auditable
          end
        RUBY
      )
      create_model_concern_file("auditable", "module Auditable; end")
      create_controller_concern_file("authenticatable", "module Authenticatable; end")
      create_model_concern_file("order_auditable", "module OrderAuditable; end")
      create_serializer_file("user_serializer", "class UserSerializer; end")
      create_job_file("user_job", "class UserJob < ApplicationJob; end")
      create_mailer_file("user_mailer", "class UserMailer < ApplicationMailer; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change the User model concern")

      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/models/concerns/auditable.rb")

      # Pollution checks:
      expect(prompt).not_to include("app/controllers/concerns/authenticatable.rb")
      expect(prompt).not_to include("app/models/concerns/order_auditable.rb")
      expect(prompt).not_to include("app/serializers/user_serializer.rb")
      expect(prompt).not_to include("app/jobs/user_job.rb")
      expect(prompt).not_to include("app/mailers/user_mailer.rb")
    end

    it "resolves Why is User validation failing? end-to-end and includes custom validator in required context" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            validates :email, email_domain: true
          end
        RUBY
      )
      create_validator_file(
        "email_domain_validator",
        <<~RUBY
          class EmailDomainValidator < ActiveModel::EachValidator
            def validate_each(record, attribute, value)
            end
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Why is User validation failing?")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/validators/email_domain_validator.rb")
      expect(prompt).to include("EmailDomainValidator")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Why is User validation failing?")
    end

    it "resolves Add email validation to User end-to-end with validates_with validator" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            validates_with CustomValidator
          end
        RUBY
      )
      create_validator_file(
        "custom_validator",
        <<~RUBY
          class CustomValidator < ActiveModel::Validator
            def validate(record)
            end
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Add email validation to User")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/validators/custom_validator.rb")
      expect(prompt).to include("CustomValidator")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Add email validation to User")
    end

    it "does not include custom validators for non-validation requests" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            validates :email, email_domain: true
          end
        RUBY
      )
      create_validator_file("email_domain_validator", "class EmailDomainValidator < ActiveModel::EachValidator; end")

      pipeline = described_class.new(tmp_project_path)

      ["Explain User", "Show User serializer", "Change UserJob"].each do |req|
        prompt = pipeline.run(req)
        expect(prompt).to be_a(String)
        expect(prompt).not_to include("app/validators/email_domain_validator.rb")
      end
    end

    it "isolates unrelated artifacts and unreferenced validators from custom validator context" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            validates :email, email_domain: true
          end
        RUBY
      )
      create_validator_file("email_domain_validator", "class EmailDomainValidator < ActiveModel::EachValidator; end")
      create_validator_file("unrelated_validator", "class UnrelatedValidator < ActiveModel::Validator; end")
      create_serializer_file("user_serializer", "class UserSerializer; end")
      create_job_file("user_job", "class UserJob < ApplicationJob; end")
      create_mailer_file("user_mailer", "class UserMailer < ApplicationMailer; end")
      create_model_concern_file("auditable", "module Auditable; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Why is User validation failing?")

      expect(prompt).to include("## REQUIRED")
      expect(prompt).to include("app/validators/email_domain_validator.rb")

      # Pollution checks:
      expect(prompt).not_to include("app/validators/unrelated_validator.rb")
      expect(prompt).not_to include("app/serializers/user_serializer.rb")
      expect(prompt).not_to include("app/jobs/user_job.rb")
      expect(prompt).not_to include("app/mailers/user_mailer.rb")
      expect(prompt).not_to include("app/models/concerns/auditable.rb")
    end

    it "resolves Change the User association with Account end-to-end and promotes related models to required context" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            belongs_to :account
            has_many :posts
          end
        RUBY
      )
      create_model_file(
        "account",
        <<~RUBY
          class Account < ApplicationRecord
            has_many :users
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change the User association with Account")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to match(/## REQUIRED\n\nFile: .*?app\/models\/account\.rb/)
      expect(prompt).to include("Account")
      expect(prompt).to include("## TASK")
      expect(prompt).to include("Change the User association with Account")
    end

    it "does not promote related models to required context for non-association edit requests" do
      create_model_file(
        "user",
        <<~RUBY
          class User < ApplicationRecord
            belongs_to :account
          end
        RUBY
      )
      create_model_file(
        "account",
        <<~RUBY
          class Account < ApplicationRecord
          end
        RUBY
      )

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Add a validation to User")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).not_to match(/## REQUIRED\n\nFile: .*?app\/models\/account\.rb/)
    end

    it "resolves Update UserService end-to-end and promotes conventional service to required context" do
      create_model_file("user", "class User < ApplicationRecord\nend")
      create_service_file("user_service", "class UserService; end")
      create_service_file("user_registration_service", "class UserRegistrationService; end")
      create_serializer_file("user_serializer", "class UserSerializer; end")
      create_job_file("user_job", "class UserJob < ApplicationJob; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Update UserService")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to match(/## REQUIRED\n\nFile: .*?app\/services\/user_service\.rb/)

      # Pollution checks:
      expect(prompt).not_to include("app/services/user_registration_service.rb")
      expect(prompt).not_to include("app/serializers/user_serializer.rb")
      expect(prompt).not_to include("app/jobs/user_job.rb")
    end

    it "does not promote conventional service to required context for non-service requests" do
      create_model_file("user", "class User < ApplicationRecord\nend")
      create_service_file("user_service", "class UserService; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Add a validation to User")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).not_to match(/## REQUIRED\n\nFile: .*?app\/services\/user_service\.rb/)
    end

    it "resolves Change User controller concern end-to-end and promotes controller concern to required context" do
      create_model_file("user", "class User < ApplicationRecord\nend")
      create_controller_file("users_controller", "class UsersController < ApplicationController\n  include Authenticatable\nend")
      create_controller_concern_file("authenticatable", "module Authenticatable; end")
      create_controller_concern_file("unrelated_concern", "module UnrelatedConcern; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Change User controller concern")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).to match(/## REQUIRED\n\nFile: .*?app\/controllers\/concerns\/authenticatable\.rb/)

      # Isolation check:
      expect(prompt).not_to include("app/controllers/concerns/unrelated_concern.rb")
    end

    it "does not promote controller concerns to required context for non-concern requests" do
      create_model_file("user", "class User < ApplicationRecord\nend")
      create_controller_file("users_controller", "class UsersController < ApplicationController\n  include Authenticatable\nend")
      create_controller_concern_file("authenticatable", "module Authenticatable; end")

      pipeline = described_class.new(tmp_project_path)
      prompt = pipeline.run("Add a validation to User")

      expect(prompt).to be_a(String)
      expect(prompt).to include("## PRIMARY")
      expect(prompt).to include("app/models/user.rb")
      expect(prompt).not_to match(/## REQUIRED\n\nFile: .*?app\/controllers\/concerns\/authenticatable\.rb/)
    end
  end
end