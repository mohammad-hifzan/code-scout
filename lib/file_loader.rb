class FileLoader
  def load(paths)
    paths.each_with_object({}) do |path, result|
      next unless File.exist?(path)

      result[path] = File.read(path)
    end
  end

  def load_context(context)
    paths = []

    paths << context[:model]

    paths << context[:primary_controller]

    paths << context[:primary_policy]

    paths.concat(
      context[:related_models]
    )

    paths.concat(
      context[:primary_views]
    )

    load(
      paths.compact.uniq
    )
  end
  
end