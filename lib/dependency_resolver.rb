# lib/dependency_graph_builder.rb

class DependencyResolver
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
  end

  def build(model_name)
    context =
      ContextBuilder
        .new(@project_map, @project_path)
        .build(model_name)
    return unless context

    direct_dependencies(context)
  end

  private

  def direct_dependencies(context)
    models =
      Array(context[:related_models]).map do |path|
        File.basename(path, ".rb").camelize
      end

    controllers =
      Array(context[:primary_controller])
        .compact
        .map { |path| File.basename(path, ".rb").camelize }

    policies =
      Array(context[:primary_policy])
        .compact
        .map { |path| File.basename(path, ".rb").camelize }

    {
      models: models,
      controllers: controllers,
      policies: policies
    }
  end
end