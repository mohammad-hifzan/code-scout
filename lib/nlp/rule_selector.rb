class RuleSelector
  def select(action)
    case action
    when :edit
      ContextRules::EditModelRule.new

    when :explain
      ContextRules::ExplainRule.new

    when :debug
      ContextRules::DebugRule.new

    else
      raise "Unknown action: #{action}"
    end
  end
end