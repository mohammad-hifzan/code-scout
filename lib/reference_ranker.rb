require 'active_support/core_ext/string'
require 'active_support/core_ext/object/blank'

class ReferenceRanker
  def initialize(model_name)
    @model_name = model_name
  end

  def rank(categorized_references)
    primary = []
    secondary = []
    tertiary = []

    return { primary: [], secondary: [], tertiary: [] } if categorized_references.nil?

    categorized_references.each_value do |files|
      files.each do |file|
        score = score(file)

        case score
        when 80..100
          primary << file
        when 40..79
          secondary << file
        else
          tertiary << file
        end
      end
    end

    {
      primary: primary.uniq,
      secondary: secondary.uniq,
      tertiary: tertiary.uniq
    }
  end

  private

  attr_reader :model_name

  def score(file)
    return generic_score(file) if model_name.blank?

    # Regex to handle namespaced paths correctly
    return 100 if file.match?(/#{Regexp.escape(model_name.underscore)}\.rb$/)
    return 90 if file.match?(/#{Regexp.escape(model_name.pluralize.underscore)}_controller\.rb$/)
    return 85 if file.match?(/#{Regexp.escape(model_name.underscore)}_policy\.rb$/)

    generic_score(file)
  end

  def generic_score(file)
    return 70 if file.include?("/app/models/")
    return 60 if file.include?("/app/controllers/")
    return 20 if file.include?("/app/views/")

    10
  end
end