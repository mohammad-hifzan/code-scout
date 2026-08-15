require "spec_helper"
require_relative "../../lib/context_rules/base_rule" # Required for inheritance
require_relative "../../lib/context_rules/edit_model_rule"

RSpec.describe ContextRules::EditModelRule do
  subject(:rule) { described_class.new }

  it "configures a comprehensive inclusion policy by returning true for all methods" do
    expect(rule.include_primary?).to be(true)
    expect(rule.include_controller?).to be(true)
    expect(rule.include_policy?).to be(true)
    expect(rule.include_related_models?).to be(true)
    expect(rule.include_views?).to be(true)
  end
end
