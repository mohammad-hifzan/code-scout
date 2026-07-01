class ContextRanker
  SCORES = {
    primary: 100,
    required: 80,
    related: 60,
    optional: 30
  }.freeze

  def rank(context)
    ranked = []

    SCORES.each do |category, score|
      Array(context[category]).each do |path|
        ranked << {
          path: path,
          category: category,
          score: score
        }
      end
    end

    ranked.sort_by { |entry| -entry[:score] }
  end
end