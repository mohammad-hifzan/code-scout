class ContextSummarizer
  def summarize(context_files)
    context_files.transform_values do |content|
      summarize_file(content)
    end
  end

  private

  def summarize_file(content)
    {
      classes: content.scan(/class\s+([A-Za-z0-9_:]+)/).flatten,
      methods: content.scan(/def\s+([a-zA-Z0-9_!?]+)/).flatten,
      associations: content.scan(
        /(belongs_to|has_many|has_one)\s+:([a-z_]+)/
      ).map { |type, name| "#{type} #{name}" }
    }
  end
end