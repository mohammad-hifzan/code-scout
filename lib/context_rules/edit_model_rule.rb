module ContextRules
  class EditModelRule < BaseRule
    def include_controller?
      true
    end

    def include_policy?
      true
    end

    def include_related_models?
      true
    end

    def include_views?
      true
    end
  end
end