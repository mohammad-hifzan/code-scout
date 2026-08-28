# lib/analysis/association_resolver.rb
require "active_support/core_ext/string/inflections"

class AssociationResolver
  def self.resolve(model_name, assoc_data, project_map = nil)
    new(project_map).resolve(model_name, assoc_data)
  end

  def initialize(project_map = nil)
    @project_map = project_map || {}
  end

  def resolve(model_name, assoc_data)
    assoc = normalize_assoc_data(assoc_data)
    return empty_result if assoc.nil? || assoc.empty?

    {
      target_model: resolve_target_model(model_name, assoc),
      through_model: resolve_through_model(model_name, assoc)
    }
  end

  def target_model(model_name, assoc_data)
    resolve(model_name, assoc_data)[:target_model]
  end

  def through_model(model_name, assoc_data)
    resolve(model_name, assoc_data)[:through_model]
  end

  private

  attr_reader :project_map

  def empty_result
    {
      target_model: nil,
      through_model: nil
    }
  end

  def normalize_assoc_data(assoc_data)
    case assoc_data
    when Hash
      assoc_data
    when Symbol, String
      { name: assoc_data.to_s }
    else
      nil
    end
  end

  def resolve_target_model(model_name, assoc)
    if assoc[:class_name] && !assoc[:class_name].to_s.empty?
      assoc[:class_name].to_s
    elsif assoc[:source] && !assoc[:source].to_s.empty?
      resolve_name(model_name, assoc[:source].to_s.singularize.camelize)
    elsif assoc[:name] && !assoc[:name].to_s.empty?
      resolve_name(model_name, assoc[:name].to_s.singularize.camelize)
    end
  end

  def resolve_through_model(model_name, assoc)
    return nil unless assoc[:through] && !assoc[:through].to_s.empty?

    through_candidate = assoc[:through].to_s.singularize.camelize
    resolve_name(model_name, through_candidate)
  end

  def resolve_name(model_name, candidate)
    return nil if candidate.nil? || candidate.empty?

    namespace = model_name.to_s.deconstantize
    if !namespace.empty?
      namespaced_candidate = "#{namespace}::#{candidate}"
      return namespaced_candidate if model_exists?(namespaced_candidate)
    end

    candidate
  end

  def model_exists?(name)
    project_map.dig(:models, name) != nil
  end
end
