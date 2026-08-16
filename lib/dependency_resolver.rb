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
    {
      models: Array(context[:related_models]).map { |path| class_name_from_path(path) }.compact,
      controllers: Array(context[:primary_controller]).map { |path| class_name_from_path(path) }.compact,
      policies: Array(context[:primary_policy]).map { |path| class_name_from_path(path) }.compact
    }
  end

  def class_name_from_path(full_path)
    return nil unless full_path

    # Extracts the path part relative to a conventional base directory
    # (e.g., app/models/, app/controllers/, or app/policies/).
    # For a path like ".../app/models/admin/user.rb", this extracts "admin/user".
    match = full_path.match(%r{app/(models|controllers|policies)/(.+)\.rb})
    return nil unless match && match[2]

    # ActiveSupport::Inflector.camelize handles the conversion from
    # "admin/user" to "Admin::User".
    match[2].camelize
  end
end