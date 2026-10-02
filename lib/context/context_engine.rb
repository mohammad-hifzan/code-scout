# lib/context_engine.rb
require_relative "../indexing/project_index"
require_relative "../context_rules/base_rule"
require_relative "../context_rules/edit_model_rule"
require_relative "context_ranker"

class ContextEngine
  TOPIC_REQUIRED_CATEGORIES = {
    serialization: %i[serializers json_views],
    policy: %i[primary_policy],
    job: %i[jobs],
    mailer: %i[mailers mailer_views],
    concern: %i[concerns],
    validation: %i[validators],
    association: %i[related_models],
    service: %i[services]
  }.freeze

  def initialize(project_index)
    @project_index = project_index
  end

  def build(entity, rule:, topic: :general, association: nil)
    model = @project_index.model(entity)
    return unless model

    context = model[:context]
    topic_sym = topic&.to_sym
    specialized_edit = rule.is_a?(ContextRules::EditModelRule) && specialized_topic?(topic_sym)

    result = {
      target: entity
    }

    if rule.include_primary?
      result[:primary] = [
        context[:model]
      ].compact
    end

    result[:required] ||= [] if specialized_edit || rule.include_controller? || rule.include_policy?
    unless specialized_edit
      if rule.include_controller? && context[:primary_controller]
        result[:required] << context[:primary_controller]
      end

      if rule.include_policy? && context[:primary_policy]
        result[:required] << context[:primary_policy]
      end
    end

    topic_files = topic_required_files(context, topic, association: association)
    if topic_files.any?
      result[:required] ||= []
      result[:required].concat(topic_files)
      result[:required].uniq!
    end

    if rule.include_related_models?
      result[:related] =
        if specialized_edit
          []
        elsif !(topic_sym == :association && association)
          Array(context[:related_models]).compact - (result[:required] || [])
        end
    end

    if rule.include_views? && !specialized_edit
      result[:optional] =
        Array(context[:primary_views]).compact
    end

    result.merge(
      ranked: ContextRanker.new.rank(result)
    )
  end

  private

  def specialized_topic?(topic)
    topic && topic != :general && TOPIC_REQUIRED_CATEGORIES.key?(topic)
  end

  def topic_required_files(context, topic, association: nil)
    return [] unless topic && context

    if topic.to_sym == :association && association
      target = context.dig(:associations, association.to_s) || context.dig(:associations, association.to_sym)
      return target ? [target] : []
    end

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