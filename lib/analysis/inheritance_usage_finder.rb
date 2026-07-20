class InheritanceUsageFinder
  IGNORED_CLASSES = %w[
    ApplicationRecord
    ApplicationController
  ].freeze

  def initialize(project_path, project_map)
    @project_path = project_path
    @project_map = project_map
  end

  def used_classes
    ruby_files.flat_map do |file|
      File.read(file).scan(/class\s+\S+\s*<\s*([A-Za-z0-9_:]+)/).flatten
    end.map do |parent_class|
      parent_class.split("::").last
    end.uniq.reject do |klass|
      IGNORED_CLASSES.include?(klass)
    end.select do |klass|
      known_classes.include?(klass)
    end
  end

  private

  def known_classes
    @known_classes ||= begin
      controllers =
        @project_map[:controllers].keys

      models =
        @project_map[:models].keys

      policies =
        Dir.glob(
          File.join(@project_path, "app/policies/**/*.rb")
        ).map do |path|
          File.basename(path, ".rb").camelize
        end

      controllers + models + policies
    end
  end

  def ruby_files
    Dir.glob(File.join(@project_path, "app/**/*.rb")) +
        Dir.glob(File.join(@project_path, "lib/**/*.rb"))
  end
end