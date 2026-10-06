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

  def build(entity, rule:, topic: :general, association: nil, service_action: nil)
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

    topic_files = topic_required_files(context, topic, association: association, service_action: service_action)
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

  def topic_required_files(context, topic, association: nil, service_action: nil)
    return [] unless topic && context

    if topic.to_sym == :association && association
      target = context.dig(:associations, association.to_s) || context.dig(:associations, association.to_sym)
      return target ? [target] : []
    end

    if topic.to_sym == :service
      return select_service_files(context, service_action)
    end

    categories = TOPIC_REQUIRED_CATEGORIES.fetch(topic.to_sym, [])
    categories.flat_map { |category| Array(context[category]).compact }
  end

  def select_service_files(context, service_action)
    services = Array(context[:services]).compact.uniq
    return [] if services.empty?

    model_name = context[:model] ? File.basename(context[:model], ".rb") : nil

    if service_action && !service_action.empty?
      action_clean = service_action.to_s.downcase
      matched = services.select do |file|
        service_file_matches_action?(file, action_clean, model_name)
      end
      return matched.take(1) if matched.size == 1
      return []
    end

    # Ambiguous or general service selection when service_action is nil:
    # If a standard conventional service (e.g. user_service.rb) is present, return it.
    if model_name
      conventional_match = services.find do |file|
        File.basename(file, ".rb").downcase == "#{model_name}_service".downcase
      end
      return [conventional_match] if conventional_match
    end

    # If only 1 service exists overall, return it
    return services if services.size == 1

    # Otherwise (multiple non-conventional services without a service_action), fail closed
    []
  end

  def service_file_matches_action?(file, action, model_name)
    action_comp = extract_service_action_component(file, model_name)
    action_comp == action || singularize(action_comp) == action || action_comp == singularize(action)
  end

  def extract_service_action_component(file, model_name)
    basename = File.basename(file, ".rb").downcase
    model_prefix = (model_name || "").downcase
    if !model_prefix.empty? && basename.start_with?("#{model_prefix}_") && basename.end_with?("_service")
      basename.delete_prefix("#{model_prefix}_").delete_suffix("_service")
    elsif basename.end_with?("_service")
      basename.delete_suffix("_service")
    else
      basename
    end
  end

  def singularize(word)
    return word if word.nil? || word.empty?

    if word.end_with?("ies") && word.length > 3
      word[0..-4] + "y"
    elsif word.end_with?("es") && word.length > 2
      word[0..-3]
    elsif word.end_with?("s") && !word.end_with?("ss") && word.length > 1
      word[0..-2]
    else
      word
    end
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