class ModelAnalyzer
  def analyze(path)
    source = File.read(path)

    {
      model: model_name(path),
      associations: extract_associations(source),
      validations: extract_validations(source),
      callbacks: extract_callbacks(source),
      scopes: extract_scopes(source),
      enums: extract_enums(source),
      includes: extract_includes(source),
      extends: extract_extends(source)
    }
  end

  private

  def model_name(path)
    File.basename(path, ".rb").camelize
  end

  def extract_associations(source)
    {
      belongs_to: source.scan(/belongs_to\s+:([a-z_]+)/).flatten,
      has_many: source.scan(/has_many\s+:([a-z_]+)/).flatten,
      has_one: source.scan(/has_one\s+:([a-z_]+)/).flatten
    }
  end

  def extract_validations(source)
    source
      .scan(/validates\s+(.+)/)
      .flatten
      .flat_map do |line|
        line.scan(/:([a-z_]+)/).flatten
      end
      .reject do |token|
        %w[
          presence
          uniqueness
          format
          length
          numericality
          inclusion
          exclusion
          acceptance
          confirmation
        ].include?(token)
      end
      .uniq
  end

  def extract_callbacks(source)
    source.scan(
      /before_\w+\s+:([a-z_]+)/i
    ).flatten.uniq
  end

  def extract_scopes(source)
    source.scan(
      /(scope|pg_search_scope)\s+:([a-z_]+)/
    ).map(&:last)
  end

  def extract_enums(source)
    source.scan(
      /enum\s+:([a-z_]+)/
    ).flatten
  end

  def extract_includes(source)
    source.scan(
      /^\s*include\s+([A-Z][A-Za-z0-9_:]+)/
    ).flatten
  end

  def extract_extends(source)
    source.scan(
      /^\s*extend\s+([A-Z][A-Za-z0-9_:]+)/
    ).flatten
  end
end