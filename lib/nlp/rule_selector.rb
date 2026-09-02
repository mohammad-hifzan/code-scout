require_relative '../context_rules/base_rule'
require_relative '../context_rules/edit_model_rule'
require_relative '../context_rules/debug_rule'
require_relative '../context_rules/explain_rule'

class RuleSelector
  def select(action)
    case action
    when :edit
      ContextRules::EditModelRule.new

    when :debug
      ContextRules::DebugRule.new

    when :explain
      ContextRules::ExplainRule.new

    else
      ContextRules::BaseRule.new
    end
  end
end