# lib/graph_builder.rb

class GraphBuilder
  def initialize(project_map)
    @project_map = project_map
  end

  def build(model_name)
    visited = []

    traverse(model_name, visited)
  end

  private

  attr_reader :project_map

  def traverse(model_name, visited)
    return nil if visited.include?(model_name)

    visited << model_name

    model = project_map[:models][model_name]
    return nil unless model

    {
      model: model_name,
      associations: {
        belongs_to: children_for(
          model[:associations][:belongs_to],
          visited
        ),
        has_many: children_for(
          model[:associations][:has_many],
          visited
        ),
        has_one: children_for(
          model[:associations][:has_one],
          visited
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