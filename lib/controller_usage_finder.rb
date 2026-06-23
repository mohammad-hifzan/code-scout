class ControllerUsageFinder
  def initialize(project_path)
    @project_path = project_path
  end

  def used_controllers
    RouteMapper
      .new(@project_path)
      .map
      .filter_map { |route| route[:controller] }
      .uniq
  end
end