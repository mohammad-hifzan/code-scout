require_relative "model_usage_finder"
require_relative "controller_usage_finder"
require_relative "policy_usage_finder"
require_relative "reference_finder"

class DeadCodeFinder
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
    @model_usage =
      ModelUsageFinder
      .new(project_map)

    @controller_usage =
      ControllerUsageFinder
      .new(project_path)

    @policy_usage =
      PolicyUsageFinder
      .new(project_map)
  end

  def find
    {
      models: unused_models,
      controllers: unused_controllers,
      policies: unused_policies,
      helpers: unused_helpers
    }
  end

  private

  def unused_models
    used_models =
      @model_usage.used_models

    @project_map[:models].keys.reject do |model|
      used_models.include?(model)
    end
  end

  def unused_controllers
    used_controllers =
      @controller_usage.used_controllers

    @project_map[:controllers].keys.reject do |controller|
      used_controllers.include?(controller)
    end
  end

  def unused_policies
    used_policies =
      @policy_usage.used_policies

    policy_files =
      Dir.glob(
        File.join(@project_path, "app/policies/**/*.rb")
      )

    policy_files.filter_map do |path|
      policy =
        File.basename(path, ".rb")
            .camelize

      policy unless used_policies.include?(policy)
    end
  end

  def unused_helpers
    helper_files =
      Dir.glob(
        File.join(@project_path, "app/helpers/**/*.rb")
      )

    helper_files.filter_map do |path|
      helper_name =
        File.basename(path, ".rb")
            .camelize

      references =
        ReferenceFinder
          .new(@project_path)
          .find(helper_name)

      helper_name if references.size <= 1
    end
  end
end