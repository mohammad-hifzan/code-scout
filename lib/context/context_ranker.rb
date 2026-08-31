require "set"

class ContextRanker
  SCORES = {
    primary: 100,
    required: 80,
    related: 60,
    optional: 30
  }.freeze

  def rank(context)
    ranked = []
    seen = Set.new

    SCORES.each do |category, score|
      Array(context[category]).compact.each do |path|
        next if seen.include?(path)

        seen << path

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