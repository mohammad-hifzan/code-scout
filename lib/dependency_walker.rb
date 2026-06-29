require "set"

class DependencyWalker
  ASSOCIATION_TYPES = %i[
    belongs_to
    has_many
    has_one
  ].freeze

  def walk_models(node)
    collect_models(node)
  end

  private

  def collect_models(node, visited = Set.new)
    model = node[:model]

    return [] unless model
    return [] if visited.include?(model)

    visited << model

    models = []

    children(node).each do |child|
      models << child[:model]
      models.concat(
        collect_models(child, visited)
      )
    end

    models
  end

  def children(node)
    ASSOCIATION_TYPES.flat_map do |type|
      node.dig(:associations, type) || []
    end
  end
end