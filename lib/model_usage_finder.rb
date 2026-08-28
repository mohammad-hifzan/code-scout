# lib/model_usage_finder.rb
require "active_support/core_ext/string/inflections"
require_relative "analysis/association_resolver"

class ModelUsageFinder
  def initialize(project_map)
    @project_map = project_map
    @association_resolver = AssociationResolver.new(project_map)
  end

  def used_models
    used = []

    @project_map[:models].each do |model_name, model|
      associations = model[:associations]
      next unless associations

      [:belongs_to, :has_many, :has_one].each do |type|
        Array(associations[type]).each do |association|
          target = @association_resolver.target_model(model_name, association)
          used << target if target
        end
      end
    end

    used.uniq
  end
end