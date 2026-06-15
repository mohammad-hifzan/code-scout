class ReferenceRanker
  def initialize(model_name)
    @model_name = model_name
  end

  def rank(categorized_references)
    primary = []
    secondary = []
    tertiary = []

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
    filename = File.basename(file)

    return 100 if filename == "#{model_name.underscore}.rb"

    return 90 if filename ==
      "#{model_name.pluralize.underscore}_controller.rb"

    return 85 if filename ==
      "#{model_name.underscore}_policy.rb"

    return 70 if file.include?("/app/models/")

    return 60 if file.include?("/app/controllers/")

    return 20 if file.include?("/app/views/")

    10
  end
end