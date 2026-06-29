# lib/dependency_analyzer.rb
require_relative "dependency_resolver"
require_relative "dependency_walker"
require_relative "graph_builder"
class DependencyAnalyzer
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
  end

  def analyze(model_name)
    resolver =
      DependencyResolver.new(
        @project_map,
        @project_path
      )

    direct = resolver.build(model_name)

    return unless direct

    graph =
      GraphBuilder
        .new(@project_map)
        .build(model_name)

    walker = DependencyWalker.new

    transitive =
      walker.walk_models(graph).uniq -
      direct[:models]

    {
      target: model_name,

      direct_dependencies: direct,

      transitive_dependencies: transitive
    }
  end
end