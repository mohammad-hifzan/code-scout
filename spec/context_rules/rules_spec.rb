require "spec_helper"

require_relative "../../lib/context_rules/base_rule"
require_relative "../../lib/context_rules/edit_model_rule"
require_relative "../../lib/context_rules/explain_rule"
require_relative "../../lib/context_rules/debug_rule"

RSpec.describe "Context Rules" do
  it "edit rule includes everything" do
    rule = ContextRules::EditModelRule.new

    expect(rule.include_primary?).to be true
    expect(rule.include_controller?).to be true
    expect(rule.include_policy?).to be true
    expect(rule.include_related_models?).to be true
    expect(rule.include_views?).to be true
  end

  it "explain rule excludes policies and views" do
    rule = ContextRules::ExplainRule.new

    expect(rule.include_primary?).to be true
    expect(rule.include_controller?).to be true
    expect(rule.include_policy?).to be false
    expect(rule.include_related_models?).to be true
    expect(rule.include_views?).to be false
  end

  it "debug rule includes everything" do
    rule = ContextRules::DebugRule.new

    expect(rule.include_primary?).to be true
    expect(rule.include_controller?).to be true
    expect(rule.include_policy?).to be true
    expect(rule.include_related_models?).to be true
    expect(rule.include_views?).to be true
  end
end