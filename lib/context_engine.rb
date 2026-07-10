# lib/context_engine.rb
require_relative "project_index"

class ContextEngine
  def initialize(project_index)
    @project_index = project_index
  end

  def build(entity, rule:)
    model = @project_index.model(entity)
    return unless model

    context = model[:context]

    result = {
      target: entity
    }

    if rule.include_primary?
      result[:primary] = [
        context[:model]
      ].compact
    end

    if rule.include_controller?
      result[:required] ||= []
      result[:required] << context[:primary_controller]
    end

    if rule.include_policy?
      result[:required] ||= []
      result[:required] << context[:primary_policy]
    end

    if rule.include_related_models?
      result[:related] =
        context[:related_models]
    end

    if rule.include_views?
      result[:optional] =
        context[:primary_views]
    end

    result.merge(
      ranked: ContextRanker.new.rank(result)
    )
  end

  private

  def primary_files(context)
    [
      context[:model]
    ].compact
  end

  def required_files(context)
    [
      context[:primary_controller],
      context[:primary_policy]
    ].compact
  end

  def related_files(context)
    context[:related_models]
  end

  def optional_files(context)
    context[:primary_views]
  end

  def sections
    %i[
      primary
      controller
      policy
      related_models
      views
    ]
  end
end