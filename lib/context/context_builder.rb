require "active_support/inflector"
require_relative "../analysis/association_resolver"
require_relative "../reference_categorizer"

class ContextBuilder
  def initialize(project_map, project_path)
    @project_map = project_map
    @project_path = project_path
    @association_resolver = AssociationResolver.new(project_map)
  end

  def build(model_name, references: nil)
    model =
      project_map.dig(:models, model_name)

    return nil unless model

    ref_categories = extract_reference_categories(references)

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
        presenters(model_name, ref_categories[:presenters])
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
end