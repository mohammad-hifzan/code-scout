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