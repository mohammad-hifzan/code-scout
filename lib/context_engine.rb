# lib/context_engine.rb
require_relative "project_index"

class ContextEngine
  def initialize(project_index)
    @project_index = project_index
  end

  def build(model_name)
    model = @project_index.model(model_name)
    return unless model

    context = {
        target: model_name,
        primary: [
        model[:context][:model]
        ].compact,
        required: [
        model[:context][:primary_controller],
        model[:context][:primary_policy]
        ].compact,
        related: model[:context][:related_models],
        optional: model[:context][:primary_views]
    }

    context.merge(
        ranked: ContextRanker.new.rank(context)
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
end