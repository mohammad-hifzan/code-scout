require_relative "reference_finder"
require_relative "reference_categorizer"
require_relative "reference_ranker"

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

    categorized =
      ReferenceCategorizer.new.categorize(references)

    ranked =
      ReferenceRanker
        .new(model_name)
        .rank(categorized)

    {
      path: model[:path],
      associations: model[:associations],
      references: categorized,
      ranked_references: ranked
    }
  end
end