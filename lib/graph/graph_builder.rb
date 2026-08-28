# lib/graph_builder.rb
require "active_support/core_ext/string/inflections"
require_relative "../analysis/model_analyzer"
require_relative "../analysis/association_resolver"

class GraphBuilder
  def initialize(project_map)
    @project_map = project_map
    @model_analyzer = ModelAnalyzer.new
    @association_resolver = AssociationResolver.new(project_map)
    @association_cache = {}
  end

  def build(model_name)
    traverse(model_name, [])
  end

  private

  attr_reader :project_map

  def get_associations(model_name)
    return @association_cache[model_name] if @association_cache.key?(model_name)

    model_info = project_map.dig(:models, model_name)
    return nil unless model_info

    analysis = @model_analyzer.analyze(model_info[:path])
    @association_cache[model_name] = analysis[:associations]
  end

  def traverse(model_name, visited)
    return nil if visited.include?(model_name)
    return nil unless project_map.dig(:models, model_name)

    associations = get_associations(model_name)
    return nil unless associations

    new_visited = visited + [model_name]

    {
      model: model_name,
      associations: {
        belongs_to: children_for(
          associations[:belongs_to],
          new_visited,
          model_name
        ),
        has_many: children_for(
          associations[:has_many],
          new_visited,
          model_name
        ),
        has_one: children_for(
          associations[:has_one],
          new_visited,
          model_name
        )
      }
    }
  end

  def children_for(associations, visited, current_model_name)
    associations.map do |assoc|
      target_model_name = @association_resolver.target_model(current_model_name, assoc)
      next unless target_model_name

      traverse(target_model_name, visited)
    end.compact
  end
end