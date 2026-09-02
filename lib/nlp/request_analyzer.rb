class RequestAnalyzer
  EDIT_KEYWORDS = %w[
    add
    create
    implement
    update
    change
    modify
    remove
    delete
    refactor
    rename
    fix
  ].freeze

  EXPLAIN_KEYWORDS = %w[
    explain
    describe
    understand
    overview
    how
    why
  ].freeze

  DEBUG_KEYWORDS = %w[
    bug
    broken
    failing
    failure
    error
    exception
    debug
    stacktrace
  ].freeze

  def initialize(models: [])
    @models = models || []
  end

  def analyze(request, models: nil)
    models_list = models || @models

    {
      action: detect_action(request),
      entity: detect_entity(request, models_list)
    }
  end

  private

  def detect_action(request)
    text = request.downcase

    # Debug signals (e.g. "NoMethodError", "debug", "broken", "failing", "bug", "exception")
    return :debug if DEBUG_KEYWORDS.any? { |k| text.include?(k) }

    # Explicit edit commands take precedence over explanation words like "how"
    return :edit if EDIT_KEYWORDS.any? { |k| text.match?(/\b#{Regexp.escape(k)}\b/i) }

    # Explain signals (e.g. "Explain Shop", "How does User work?")
    return :explain if EXPLAIN_KEYWORDS.any? { |k| text.match?(/\b#{Regexp.escape(k)}\b/i) }

    :edit
  end

  def detect_entity(request, models)
    return nil if models.nil? || models.empty?

    lookup = build_model_lookup(models)
    tokens = request.scan(/[A-Za-z0-9_:]+(?:'s|')?/i)

    tokens.each do |token|
      clean_token = token.sub(/'s\z/i, "").sub(/'\z/, "")
      downcased = clean_token.downcase

      matched = lookup[downcased] || lookup[singularize(downcased)]
      return matched if matched
    end

    nil
  end

  def build_model_lookup(models)
    lookup = {}

    models.each do |model_name|
      # 1. Exact downcase e.g. "user" => "User", "billing::invoice" => "Billing::Invoice"
      lookup[model_name.downcase] ||= model_name

      # 2. Plural variations e.g. "users" => "User"
      plural_variants(model_name.downcase).each do |plural|
        lookup[plural] ||= model_name
      end

      # 3. For namespaced models like "Billing::Invoice", also map demodulized "invoice" and "invoices"
      if model_name.include?("::")
        demodulized = model_name.split("::").last.downcase
        lookup[demodulized] ||= model_name
        plural_variants(demodulized).each do |plural|
          lookup[plural] ||= model_name
        end
      end
    end

    lookup
  end

  def plural_variants(word)
    variants = [word]
    if word.end_with?("y") && !word.end_with?("ay", "ey", "iy", "oy", "uy")
      variants << word[0..-2] + "ies"
    elsif word.end_with?("s", "x", "z", "ch", "sh")
      variants << word + "es"
    else
      variants << word + "s"
    end
    variants
  end

  def singularize(word)
    return word if word.nil? || word.empty?

    if word.end_with?("ies") && word.length > 3
      word[0..-4] + "y"
    elsif word.end_with?("es") && word.length > 2
      word[0..-3]
    elsif word.end_with?("s") && !word.end_with?("ss") && word.length > 1
      word[0..-2]
    else
      word
    end
  end
end