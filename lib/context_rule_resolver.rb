require_relative "context_rules/edit_model_rule"
require_relative "context_rules/explain_rule"
require_relative "context_rules/debug_rule"

class ContextRuleResolver
  def resolve(task)
    case task.to_s
    when "edit"
      ContextRules::EditModelRule.new

    when "explain"
      ContextRules::ExplainRule.new

    when "debug"
      ContextRules::DebugRule.new

    else
      ContextRules::EditModelRule.new
    end
  end
end