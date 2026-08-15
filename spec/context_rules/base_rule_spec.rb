require "spec_helper"
require_relative "../../lib/context_rules/base_rule"

RSpec.describe ContextRules::BaseRule do
  subject(:rule) { described_class.new }

  describe "default rule configuration" do
    it "sets default inclusion rules correctly" do
      expect(rule.include_primary?).to be(true)
      expect(rule.include_controller?).to be(false)
      expect(rule.include_policy?).to be(false)
      expect(rule.include_related_models?).to be(false)
      expect(rule.include_views?).to be(false)
    end
  end
end
