require "active_support/inflector"
require "pathname"

class ProjectMapper
  def initialize(project_path)
    @project_path = project_path
  end

  def map
    {
      models: models,
      controllers: controllers,
      views: views
    }
  end

  private

  attr_reader :project_path

  def extract_associations(model_path)
    content = File.read(model_path)

    {
      belongs_to: content.scan(/belongs_to\s+:([a-z_]+)/).flatten,
      has_many: content.scan(/has_many\s+:([a-z_]+)/).flatten,
      has_one: content.scan(/has_one\s+:([a-z_]+)/).flatten
    }
  end

  def controllers
    controllers_dir = File.join(project_path, "app/controllers")
    Dir.glob(
      File.join(controllers_dir, "**/*_controller.rb")
    ).each_with_object({}) do |path, result|
      relative_path = Pathname.new(path).relative_path_from(Pathname.new(controllers_dir)).to_s
      class_name_part = relative_path.sub(/_controller\.rb$/, "")
      controller_name = "#{class_name_part.camelize}Controller"

      next if controller_name == "ApplicationController"

      result[controller_name] = {
        path: path
      }
    end
  end

  def models
    models_dir = File.join(project_path, "app/models")
    Dir.glob(
      File.join(models_dir, "**/*.rb")
    ).each_with_object({}) do |path, result|
      relative_path = Pathname.new(path).relative_path_from(Pathname.new(models_dir)).to_s
      model_name = relative_path.sub(/\.rb$/, "").camelize

      next if model_name == "ApplicationRecord"

      result[model_name] = {
        path: path,
        associations: extract_associations(path)
      }
    end
  end

  def views
    result = {}

    Dir.glob(
      File.join(project_path, "app/views/*")
    ).select { |path| File.directory?(path) }
    .each do |folder|
        view_name = File.basename(folder)

        result[view_name] = Dir.glob(
          File.join(folder, "**/*")
        ).select { |path| File.file?(path) }
    end

    result
  end
end