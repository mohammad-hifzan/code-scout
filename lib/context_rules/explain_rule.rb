module ContextRules
  class ExplainRule < BaseRule
    def include_controller?
      true
    end

    def include_related_models?
      true
    end
  end
end