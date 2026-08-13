class PolicyUsageFinder
  def initialize(project_map)
    @project_map = project_map
  end

  def used_policies
    models = @project_map&.[](:models)
    return [] if models.nil?

    models.keys.map do |model_name|
      "#{model_name}Policy"
    end
  end
end