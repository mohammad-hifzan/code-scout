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
      .with("Shop", rule: rule)
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
    expect(analyzer).to receive(:analyze).with(request).and_return({ action: :edit, entity: nil })
    expect(selector).to receive(:select).with(:edit).and_return(rule)
    expect(engine).to receive(:build).with(nil, rule: rule).and_return(nil)

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
  end
end