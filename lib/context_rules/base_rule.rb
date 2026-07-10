module ContextRules
  class BaseRule
    def include_primary?
      true
    end

    def include_controller?
      false
    end

    def include_policy?
      false
    end

    def include_related_models?
      false
    end

    def include_views?
      false
    end
  end
end