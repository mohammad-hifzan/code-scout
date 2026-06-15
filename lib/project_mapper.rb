require "active_support/inflector"

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
    Dir.glob(
      File.join(project_path, "app/controllers/**/*_controller.rb")
    ).each_with_object({}) do |path, result|
      controller_name = File.basename(path, ".rb").camelize
      next if controller_name == "ApplicationController"

      result[controller_name] = {
        path: path
      }
    end
  end

  def models
    result = {}

    Dir.glob(
      File.join(project_path, "app/models/**/*.rb")
    ).each do |path|

      model_name = File.basename(path, ".rb").camelize

      next if model_name == "ApplicationRecord"

      result[model_name] = {
        path: path,
        associations: extract_associations(path)
      }
    end

    result
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