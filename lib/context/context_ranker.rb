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
    evidence = context[:evidence]

    SCORES.each do |category, score|
      category_paths = []
      Array(context[category]).compact.each do |path|
        next if seen.include?(path)

        seen << path
        category_paths << path
      end

      sorted_paths = category_paths.sort_by.with_index do |path, index|
        [evidence_tier(path, evidence), index]
      end

      sorted_paths.each do |path|
        ranked << {
          path: path,
          category: category,
          score: score
        }
      end
    end

    ranked.sort_by { |entry| -entry[:score] }
  end

  private

  def evidence_tier(path, evidence)
    return 2 unless evidence

    tags = Array(evidence[path])
    return 2 if tags.empty?
    return 1 if tags.any? { |tag| tag != :rule_fallback }

    3
  end
end