# lib/model_usage_finder.rb
require 'active_support/core_ext/string/inflections'

class ModelUsageFinder
  def initialize(project_map)
    @project_map = project_map
  end

  def used_models
    used = []

    @project_map[:models].each_value do |model|
      associations = model[:associations]

      [:belongs_to, :has_many, :has_one].each do |type|
        associations[type].each do |association|
          model_name = if association.is_a?(Hash) && association[:class_name]
            association[:class_name]
          else
            association.to_s.singularize.camelize
          end
          used << model_name
        end
      end
    end

    used.uniq
  end
end