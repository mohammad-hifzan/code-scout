require "active_support/inflector"
require_relative "../analysis/association_resolver"
require_relative "../analysis/model_analyzer"
require_relative "../analysis/controller_analyzer"
require_relative "../reference_categorizer"

class ContextBuilder
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
    @association_resolver = AssociationResolver.new(project_map)
    @model_analyzer = ModelAnalyzer.new
    @controller_analyzer = ControllerAnalyzer.new
  end

  def build(model_name, references: nil, analysis: nil)
    model =
      project_map.dig(:models, model_name)

    return nil unless model

    ref_categories = extract_reference_categories(references)

    model_analysis = analysis || (model[:path] && File.exist?(model[:path]) ? @model_analyzer.analyze(model[:path]) : nil)

    {
      model: model[:path],

      primary_controller:
        primary_controller(model_name),

      primary_policy:
        primary_policy(model_name),

      related_models:
        related_models(model, model_name),

      primary_views:
        primary_views(model_name),

      serializers:
        serializers(model, model_name, ref_categories[:serializers]),

      json_views:
        json_views(model_name),

      presenters:
        presenters(model_name, ref_categories[:presenters]),

      jobs:
        jobs(model_name, ref_categories[:jobs]),

      mailers:
        mailers(model_name, ref_categories[:mailers]),

      mailer_views:
        mailer_views(model_name),

      concerns:
        concerns(model, model_name, ref_categories[:concerns], model_analysis),

      validators:
        validators(model, model_name, model_analysis),

      services:
        services(model_name)
    }
  end

  private

  attr_reader :project_map, :project_path

  def primary_controller(model_name)
    controller_name =
      "#{model_name.pluralize}Controller"

    controller =
      project_map.dig(:controllers, controller_name)

    controller&.dig(:path)
  end

  def primary_policy(model_name)
    policy_file =
      File.join(
        project_path,
        "app/policies/#{model_name.underscore}_policy.rb"
      )

    File.exist?(policy_file) ? policy_file : nil
  end

  def related_models(model, current_model_name = nil)
    associations =
      model[:associations]

    return [] unless associations

    associations.values.flatten.filter_map do |assoc|
      resolved = @association_resolver.resolve(current_model_name, assoc)
      direct_model_name = resolved[:through_model] || resolved[:target_model]
      next unless direct_model_name

      project_map.dig(:models, direct_model_name, :path)
    end.uniq
  end

  def extract_reference_categories(references)
    return {} if references.nil?

    if references.is_a?(Hash)
      references
    else
      ReferenceCategorizer.new.categorize(references)
    end
  end

  def primary_views(model_name)
    # Converts a model name like 'User' to 'users' or 'Admin::User' to 'admin/users'.
    # This is the conventional directory name for views related to a model.
    view_directory = model_name.underscore.pluralize

    # Construct a path pattern to find all .erb files within that specific view directory.
    # e.g., /path/to/project/app/views/users/**/*.erb
    path_pattern = File.join(project_path, "app/views", view_directory, "**", "*.erb")

    Dir.glob(path_pattern)
  end

  def serializers(model, model_name, ref_serializers = nil)
    files = []

    # 1. Primary serializer (e.g. app/serializers/user_serializer.rb)
    primary_serializer = File.join(project_path, "app/serializers/#{model_name.underscore}_serializer.rb")
    files << primary_serializer if File.exist?(primary_serializer)

    # 2. Serializers for directly associated models (e.g. app/serializers/post_serializer.rb)
    if model && model[:associations]
      model[:associations].values.flatten.each do |assoc|
        resolved = @association_resolver.resolve(model_name, assoc)
        direct_model_name = resolved[:through_model] || resolved[:target_model]
        next unless direct_model_name

        assoc_serializer = File.join(project_path, "app/serializers/#{direct_model_name.underscore}_serializer.rb")
        files << assoc_serializer if File.exist?(assoc_serializer)
      end
    end

    # 3. Reference-derived serializers
    files.concat(ref_serializers) if ref_serializers

    files.uniq
  end

  def json_views(model_name)
    view_directory = model_name.underscore.pluralize
    jbuilder_pattern = File.join(project_path, "app/views", view_directory, "**", "*.jbuilder")
    Dir.glob(jbuilder_pattern)
  end

  def presenters(model_name, ref_presenters = nil)
    presenter_file = File.join(project_path, "app/presenters/#{model_name.underscore}_presenter.rb")
    files = File.exist?(presenter_file) ? [presenter_file] : []
    files.concat(ref_presenters) if ref_presenters
    files.uniq
  end

  def jobs(model_name, ref_jobs = nil)
    files = []

    # 1. Conventional ActiveJob (e.g. app/jobs/user_job.rb)
    job_file = File.join(project_path, "app/jobs/#{model_name.underscore}_job.rb")
    files << job_file if File.exist?(job_file)

    # 2. Conventional Worker (e.g. app/workers/user_worker.rb)
    worker_file = File.join(project_path, "app/workers/#{model_name.underscore}_worker.rb")
    files << worker_file if File.exist?(worker_file)

    # 3. Reference-derived jobs
    files.concat(ref_jobs) if ref_jobs

    files.uniq
  end

  def mailers(model_name, ref_mailers = nil)
    files = []

    # 1. Conventional ActionMailer (e.g. app/mailers/user_mailer.rb)
    mailer_file = File.join(project_path, "app/mailers/#{model_name.underscore}_mailer.rb")
    files << mailer_file if File.exist?(mailer_file)

    # 2. Reference-derived mailers
    files.concat(ref_mailers) if ref_mailers

    files.uniq
  end

  def mailer_views(model_name)
    pattern = File.join(project_path, "app/views/#{model_name.underscore}_mailer", "**", "*")
    Dir.glob(pattern).select { |f| File.file?(f) }
  end

  def concerns(model, model_name, ref_concerns = nil, analysis = nil)
    files = []
    files.concat(model_concerns(model, ref_concerns, analysis))
    files.concat(controller_concerns(model_name))
    files.uniq
  end

  def model_concerns(model, ref_concerns = nil, analysis = nil)
    files = []

    # 1. Direct AST evidence (includes & extends)
    if model && model[:path] && File.exist?(model[:path])
      model_data = analysis || @model_analyzer.analyze(model[:path])
      modules = (Array(model_data[:includes]) + Array(model_data[:extends])).uniq

      modules.each do |mod|
        next if mod.nil? || mod.empty?

        concern_path = File.join(project_path, "app/models/concerns", "#{mod.underscore}.rb")
        files << concern_path if File.exist?(concern_path)
      end
    end

    # 2. Reference-derived model concerns (filtered strictly to app/models/concerns/)
    if ref_concerns
      model_ref_concerns = ref_concerns.select do |f|
        f.to_s.include?("/app/models/concerns/") && File.exist?(f)
      end
      files.concat(model_ref_concerns)
    end

    files.uniq
  end

  def controller_concerns(model_name)
    controller_path = primary_controller(model_name)
    return [] unless controller_path && File.exist?(controller_path)

    analysis = @controller_analyzer.analyze(controller_path)
    modules = Array(analysis[:modules]).uniq
    return [] if modules.empty?

    concerns_root = File.expand_path(File.join(project_path, "app/controllers/concerns"))
    concerns_prefix = "#{concerns_root}/"

    files = []
    modules.each do |mod|
      next if mod.nil? || mod.empty?

      relative_file = "#{mod.delete_prefix('::').underscore}.rb"
      candidate = File.expand_path(File.join(concerns_root, relative_file))
      next unless candidate.start_with?(concerns_prefix)
      next unless File.exist?(candidate)

      files << candidate
    end

    files.uniq
  end

  def validators(model, model_name, analysis = nil)
    return [] unless model && model[:path] && File.exist?(model[:path])

    model_data = analysis || @model_analyzer.analyze(model[:path])
    validator_names = Array(model_data[:validators])
    return [] if validator_names.empty?

    validator_root = File.expand_path(File.join(project_path, "app/validators"))
    validator_prefix = "#{validator_root}/"

    files = []
    validator_names.each do |val|
      next if val.nil? || val.empty?

      relative_file = "#{val.delete_prefix('::').underscore}.rb"
      candidate = File.expand_path(File.join(validator_root, relative_file))
      next unless candidate.start_with?(validator_prefix) || candidate == validator_root
      next unless File.exist?(candidate)

      files << candidate
    end

    files.uniq
  end

  def services(model_name)
    return [] if model_name.nil? || model_name.empty?

    services_root = File.expand_path(File.join(project_path, "app/services"))
    services_prefix = "#{services_root}/"

    relative_file = "#{model_name.underscore}_service.rb"
    candidate = File.expand_path(File.join(services_root, relative_file))

    return [] unless candidate.start_with?(services_prefix)
    return [] unless File.exist?(candidate)

    [candidate]
  end
end