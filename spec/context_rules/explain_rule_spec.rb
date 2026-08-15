# spec/context_rules/explain_rule_spec.rb
require 'spec_helper'
require_relative '../../lib/context_rules/base_rule'
require_relative '../../lib/context_rules/explain_rule'

RSpec.describe ContextRules::ExplainRule do
  subject(:rule) { described_class.new }

  it 'indicates that controllers should be included' do
    expect(rule.include_controller?).to be(true)
  end

  it 'indicates that related models should be included' do
    expect(rule.include_related_models?).to be(true)
  end
end
