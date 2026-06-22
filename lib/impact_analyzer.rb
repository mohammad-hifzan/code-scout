class ImpactAnalyzer
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
  end

  def analyze(model_name)
    context =
      ContextBuilder
      .new(@project_map, @project_path)
      .build(model_name)

    return unless context

    graph =
      GraphBuilder.new(@project_map).build(model_name)

    direct_models =
      context[:related_models]
        .map { |path| File.basename(path, ".rb").camelize }

    indirect_models =
      collect_indirect_models(graph)
        .uniq - direct_models - [model_name]

    
    score =
      direct_models.size * 3 +
      indirect_models.size +
      ([context[:primary_controller]].compact.size * 2) +
      ([context[:primary_policy]].compact.size * 2)

    {
      target: model_name,
      score: score,
      risk_level: risk_level(score),

      direct_impact: {
        models: direct_models,
        controllers: [context[:primary_controller]].compact,
        policies: [context[:primary_policy]].compact
      },

      indirect_impact: {
        models: indirect_models
      }
    }
  end

  def collect_indirect_models(node, visited = Set.new)
    return [] if visited.include?(node[:model])

    visited << node[:model]

    models = []

    [:belongs_to, :has_many, :has_one].each do |type|
      node[:associations][type].each do |child|
        models << child[:model]
        models.concat(
          collect_indirect_models(child, visited)
        )
      end
    end

    models
  end

  def risk_level(score)
    case score
    when 0..5
      :low
    when 6..15
      :medium
    else
      :high
    end
  end

end