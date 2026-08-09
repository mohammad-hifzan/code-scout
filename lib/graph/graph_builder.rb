# lib/graph_builder.rb
require "active_support/core_ext/string/inflections"

class GraphBuilder
  def initialize(project_map)
    @project_map = project_map
  end

  def build(model_name)
    traverse(model_name, [])
  end

  private

  attr_reader :project_map

  def traverse(model_name, visited)
    return nil if visited.include?(model_name)

    model = project_map.dig(:models, model_name)
    return nil unless model

    new_visited = visited + [model_name]

    {
      model: model_name,
      associations: {
        belongs_to: children_for(
          model[:associations][:belongs_to],
          new_visited
        ),
        has_many: children_for(
          model[:associations][:has_many],
          new_visited
        ),
        has_one: children_for(
          model[:associations][:has_one],
          new_visited
        )
      }
    }
  end

  def children_for(names, visited)
    names.map do |name|
      traverse(name.singularize.camelize, visited)
    end.compact
  end
end