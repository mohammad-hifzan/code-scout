# lib/model_usage_finder.rb

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
          used << association.to_s.singularize.camelize
        end
      end
    end

    used.uniq
  end
end