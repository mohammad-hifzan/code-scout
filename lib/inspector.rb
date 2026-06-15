require_relative "reference_finder"
require_relative "reference_categorizer"
class Inspector
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
  end

  def inspect_model(model_name)
    model = @project_map[:models][model_name]

    return nil unless model

    references =
      ReferenceFinder.new(@project_path).find(model_name)

    {
      path: model[:path],
      associations: model[:associations],
      references: ReferenceCategorizer.new.categorize(references)
    }
  end
end