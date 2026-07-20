# lib/project_index.rb

require_relative "../analysis/model_analyzer"
require_relative "../analysis/controller_analyzer"
require_relative "../analysis/view_analyzer"
require_relative "../context/context_builder"
require_relative "../analysis/dependency_analyzer"
require_relative "../analysis/impact_analyzer"

class ProjectIndex
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path

    @model_cache = {}
    @controller_cache = {}
    @view_cache = {}

    @context_builder =
      ContextBuilder.new(project_map, project_path)

    @dependency_analyzer =
      DependencyAnalyzer.new(project_map, project_path)

    @impact_analyzer =
      ImpactAnalyzer.new(project_map, project_path)
  end

  #
  # Models
  #
  def model(name)
    @model_cache[name] ||= build_model(name)
  end

  #
  # Controllers
  #
  def controller(name)
    @controller_cache[name] ||= build_controller(name)
  end

  #
  # Views
  #
  # path should be the absolute path to the view file.
  #
  def view(path)
    @view_cache[path] ||= build_view(path)
  end

  private

  def build_model(name)
    model = @project_map[:models][name]
    return unless model

    {
      analyzer:
        ModelAnalyzer.new.analyze(model[:path]),

      context:
        @context_builder.build(name),

      dependency:
        @dependency_analyzer.analyze(name),

      impact:
        @impact_analyzer.analyze(name)
    }
  end

  def build_controller(name)
    controller = @project_map[:controllers][name]
    return unless controller

    {
      analyzer:
        ControllerAnalyzer.new.analyze(controller[:path])
    }
  end

  def build_view(path)
    return unless File.exist?(path)

    {
      analyzer:
        ViewAnalyzer.new.analyze(path)
    }
  end
end