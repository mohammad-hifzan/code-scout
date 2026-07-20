class FileLoader
  def load(paths)
    paths.each_with_object({}) do |path, result|
      next unless File.exist?(path)

      result[path] = File.read(path)
    end
  end

  def load_files(files)
    contents = load(files.map { |file| file[:path] })

    files.map do |file|
      file.merge(
        content: contents[file[:path]]
      )
    end
  end
end