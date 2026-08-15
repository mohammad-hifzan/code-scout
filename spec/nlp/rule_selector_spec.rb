# spec/nlp/rule_selector_spec.rb
require 'spec_helper'
require_relative '../../lib/nlp/rule_selector'
require_relative '../../lib/context_rules/base_rule'
require_relative '../../lib/context_rules/edit_model_rule'
require_relative '../../lib/context_rules/debug_rule'
require_relative '../../lib/context_rules/explain_rule'

RSpec.describe RuleSelector do
  subject(:selector) { described_class.new }

  it 'returns a BaseRule for an unknown action' do
    rule = selector.select(:some_unknown_action)
    expect(rule).to be_a(ContextRules::BaseRule)
  end
end
