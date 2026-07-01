class TokenEstimator
  CHARS_PER_TOKEN = 4.0

  def estimate(items)
    items.map do |item|
      item.merge(
        estimated_tokens: estimate_file(item[:path])
      )
    end
  end

  private

  def estimate_file(path)
    return 0 unless File.exist?(path)

    (File.read(path).size / CHARS_PER_TOKEN).ceil
  end
end