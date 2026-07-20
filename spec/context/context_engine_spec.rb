require "spec_helper"

require_relative "../../lib/indexing/project_mapper"
require_relative "../../lib/indexing/project_index"

require_relative "../../lib/context/context_engine"
require_relative "../../lib/context/context_ranker"

require_relative "../../lib/context_rules/base_rule"
require_relative "../../lib/context_rules/edit_model_rule"
require_relative "../../lib/context_rules/explain_rule"
require_relative "../../lib/context_rules/debug_rule"

RSpec.describe ContextEngine do
  let(:project_map) do
    ProjectMapper.new(fixture_project).map
  end

  let(:index) do
    ProjectIndex.new(
      project_map,
      fixture_project
    )
  end

  subject(:engine) do
    described_class.new(index)
  end

  describe "#build" do
    context "with EditModelRule" do
      it "builds edit context" do
        context_result =
          engine.build(
            "Shop",
            rule: ContextRules::EditModelRule.new
          )

        expect(context_result).not_to be_nil

        expect(context_result[:primary]).not_to be_empty
        expect(context_result[:required]).not_to be_empty
        expect(context_result[:related]).not_to be_empty
        expect(context_result[:optional]).not_to be_empty

        expect(context_result[:ranked]).not_to be_empty

        expect(
          context_result[:ranked].first[:category]
        ).to eq(:primary)
      end
    end

    context "with ExplainRule" do
      it "builds explain context" do
        context_result =
          engine.build(
            "Shop",
            rule: ContextRules::ExplainRule.new
          )

        expect(context_result).not_to be_nil

        expect(context_result[:primary]).not_to be_empty
        expect(context_result[:required]).not_to be_empty
        expect(context_result[:related]).not_to be_empty

        expect(
          context_result.key?(:optional)
        ).to be(false)

        expect(context_result[:ranked]).not_to be_empty
      end
    end

    context "with DebugRule" do
      it "builds debug context" do
        context_result =
          engine.build(
            "Shop",
            rule: ContextRules::DebugRule.new
          )

        expect(context_result).not_to be_nil

        expect(context_result[:primary]).not_to be_empty
        expect(context_result[:required]).not_to be_empty
        expect(context_result[:related]).not_to be_empty
        expect(context_result[:optional]).not_to be_empty

        expect(context_result[:ranked]).not_to be_empty
      end
    end

    context "with an unknown model" do
      it "returns nil" do
        result =
          engine.build(
            "UnknownModel",
            rule: ContextRules::EditModelRule.new
          )

        expect(result).to be_nil
      end
    end
  end
end