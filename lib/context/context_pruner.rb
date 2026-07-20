class ContextPruner
  def prune(items, max_tokens:)
    selected = []
    total = 0

    items.each do |item|
      tokens = item[:estimated_tokens]

      next if total + tokens > max_tokens

      selected << item
      total += tokens
    end

    {
      files: selected,
      total_tokens: total,
      budget: max_tokens
    }
  end
end