# lib/graph_builder.rb
require "active_support/core_ext/string/inflections"
require_relative "../analysis/model_analyzer"

class GraphBuilder
  def initialize(project_map)
    @project_map = project_map
    @model_analyzer = ModelAnalyzer.new
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
          new_visited
        ),
        has_many: children_for(
          associations[:has_many],
          new_visited
        ),
        has_one: children_for(
          associations[:has_one],
          new_visited
        )
      }
    }
  end

  def children_for(associations, visited)
    associations.map do |assoc|
      target_model_name =
        if assoc[:class_name]
          assoc[:class_name]
        else
          assoc[:name].singularize.camelize
        end
      traverse(target_model_name, visited)
    end.compact
  end
end