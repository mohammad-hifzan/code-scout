# lib/context_engine.rb
require_relative "../indexing/project_index"
require_relative "context_ranker"

class ContextEngine
  TOPIC_REQUIRED_CATEGORIES = {
    serialization: %i[serializers json_views]
  }.freeze

  def initialize(project_index)
    @project_index = project_index
  end

  def build(entity, rule:, topic: :general)
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
      result[:required] << context[:primary_controller] if context[:primary_controller]
    end

    if rule.include_policy?
      result[:required] ||= []
      result[:required] << context[:primary_policy] if context[:primary_policy]
    end

    topic_files = topic_required_files(context, topic)
    if topic_files.any?
      result[:required] ||= []
      result[:required].concat(topic_files)
      result[:required].uniq!
    end

    if rule.include_related_models?
      result[:related] =
        Array(context[:related_models]).compact
    end

    if rule.include_views?
      result[:optional] =
        Array(context[:primary_views]).compact
    end

    result.merge(
      ranked: ContextRanker.new.rank(result)
    )
  end

  private

  def topic_required_files(context, topic)
    return [] unless topic && context

    categories = TOPIC_REQUIRED_CATEGORIES.fetch(topic.to_sym, [])
    categories.flat_map { |category| Array(context[category]).compact }
  end

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