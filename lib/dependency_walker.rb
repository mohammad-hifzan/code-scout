require "set"

class DependencyWalker
  ASSOCIATION_TYPES = %i[
    belongs_to
    has_many
    has_one
  ].freeze

  def walk_models(node)
    return [] if node.nil? # Handle nil input

    collected_dependencies = Set.new
    path_visited = Set.new # Tracks models in the current recursion path to detect cycles

    current_model_name = node[:model]
    return [] if current_model_name.nil? # Handles nodes like { associations: {} }

    path_visited << current_model_name # Mark root as visited for cycle detection in its branches

    children(node).each do |child|
      # Pass a copy of path_visited for each branch to isolate their cycle detection
      _collect_recursive(child, path_visited.dup, collected_dependencies)
    end

    collected_dependencies.to_a
  end

  private

  def _collect_recursive(node, path_visited, collected_dependencies)
    return if node.nil? # Handle nil child nodes gracefully

    model_name = node[:model]

    return if model_name.nil? # Handle child nodes with nil model or missing model key
    return if path_visited.include?(model_name) # Detect cycle in current path

    path_visited << model_name # Add to current path for cycle detection
    collected_dependencies << model_name # Add to the global set of collected unique models

    children(node).each do |child|
      # Pass a copy of path_visited to children to ensure cycle detection is isolated per branch
      _collect_recursive(child, path_visited.dup, collected_dependencies)
    end
  end

  def children(node)
    ASSOCIATION_TYPES.flat_map do |type|
      node.dig(:associations, type) || []
    end
  end
end
