require "active_support/inflector"
class ContextBuilder
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
  end

  def build(model_name)
    model =
      project_map[:models][model_name]

    return nil unless model

    {
      model: model[:path],

      primary_controller:
        primary_controller(model_name),

      primary_policy:
        primary_policy(model_name),

      related_models:
        related_models(model),

      primary_views:
        primary_views(model_name)
    }
  end

  private

  attr_reader :project_map, :project_path

  def primary_controller(model_name)
    controller_name =
      "#{model_name.pluralize}Controller"

    controller =
      project_map[:controllers][controller_name]

    controller&.dig(:path)
  end

  def primary_policy(model_name)
    policy_file =
      File.join(
        project_path,
        "app/policies/#{model_name.underscore}_policy.rb"
      )

    File.exist?(policy_file) ? policy_file : nil
  end

  def related_models(model)
    associations =
      model[:associations]

    names =
      associations.values.flatten

    names.filter_map do |name|
      model_name =
        name.to_s.singularize.camelize

      project_map[:models][model_name]
        &.dig(:path)
    end
  end

  def primary_views(model_name)
    # Converts a model name like 'User' to 'users' or 'Admin::User' to 'admin/users'.
    # This is the conventional directory name for views related to a model.
    view_directory = model_name.underscore.pluralize

    # Construct a path pattern to find all .erb files within that specific view directory.
    # e.g., /path/to/project/app/views/users/**/*.erb
    path_pattern = File.join(project_path, "app/views", view_directory, "**", "*.erb")

    Dir.glob(path_pattern)
  end
  
end