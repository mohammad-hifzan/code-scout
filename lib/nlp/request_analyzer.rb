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

  TOPIC_PATTERNS = {
    validation: [
      /\bvalidat(ion|e|es|or|ions|ors)\b/i,
      /\b\w*validator(s)?\b/i
    ],
    serialization: [
      /\b\w*serializer(s)?\b/i,
      /\b(serialize|serialized|serialization|as_json|jbuilder)\b/i,
      /\bjson(\s+representation)?\b/i
    ],
    job: [
      /\b[A-Za-z0-9_:]+(?:job|worker)(?:s)?\b/i,
      /\bbackground\s+(?:job|worker)(?:s)?\b/i,
      /\b(?:sidekiq|active_?job|resque|shoryuken)\b/i,
      /\b(?:perform_later|perform_async|perform_now|perform_in|perform_at)\b/i,
      /\bperform\s+method\b/i,
      /\b\w+\s+(?:job|worker)(?:s)?\s+(?:is|are|failing|failed|broken|error|failure)\b/i,
      /\b(?:the\s+)?\w+\s+(?:job|worker)(?:s)?\s+failing\b/i
    ],
    mailer: [
      /\b[A-Za-z0-9_:]+mailer(s)?\b/i,
      /\b(?:email|mailer)\s+template(s)?\b/i,
      /\bemail\s+delivery\b/i,
      /\bdeliver\s+mail\b/i,
      /\b(?:deliver_later|deliver_now)\b/i,
      /\baction_?mailer\b/i
    ],
    service: [
      /\bservice\s+object(s)?\b/i,
      /\b\w*service(s)?\b/i,
      /\binteractor(s)?\b/i,
      /\buse\s+case(s)?\b/i
    ],
    policy: [
      /\b\w*policy\b/i,
      /\bauthoriz(e|ation)\b/i,
      /\bpundit\b/i
    ],
    concern: [
      /\b[A-Za-z0-9_:]+concern(s)?\b/i,
      /\bthe\s+[A-Za-z0-9_:]+\s+concern\b/i,
      /\b(?:model|controller)\s+concern(s)?\b/i,
      /\b(?:model\s+)?mixin(s)?\b/i,
      /\bactive_?support(?:::|\s+)concern\b/i
    ],
    association: [
      /\b(association|associations|relationship|relationships)\b/i,
      /\b(belongs_to|has_many|has_one|has_and_belongs_to_many)\b/i
    ]
  }.freeze

  ARTIFACT_SUFFIXES = %w[
    serializer
    policy
    job
    worker
    mailer
    service
  ].freeze

  def initialize(models: [])
    @models = models || []
  end

  def analyze(request, models: nil)
    models_list = models || @models

    {
      action: detect_action(request),
      entity: detect_entity(request, models_list),
      topic: detect_topic(request)
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

    # 1. Direct model name resolution
    tokens.each do |token|
      clean_token = token.sub(/'s\z/i, "").sub(/'\z/, "")
      downcased = clean_token.downcase

      matched = lookup[downcased] || lookup[singularize(downcased)]
      return matched if matched
    end

    # 2. Rails compound artifact resolution (e.g. UserSerializer -> User)
    tokens.each do |token|
      clean_token = token.sub(/'s\z/i, "").sub(/'\z/, "")
      matched = resolve_compound_entity(clean_token, lookup)
      return matched if matched
    end

    nil
  end

  def resolve_compound_entity(token, lookup)
    downcased = token.downcase

    ARTIFACT_SUFFIXES.each do |suffix|
      if downcased.end_with?(suffix) && downcased.length > suffix.length
        base = downcased[0...-suffix.length].sub(/_\z/, "")
        matched = lookup[base] || lookup[singularize(base)]
        return matched if matched
      end

      singular = singularize(downcased)
      if singular != downcased && singular.end_with?(suffix) && singular.length > suffix.length
        base = singular[0...-suffix.length].sub(/_\z/, "")
        matched = lookup[base] || lookup[singularize(base)]
        return matched if matched
      end
    end

    nil
  end

  def detect_topic(request)
    text = request.downcase

    detected = []
    TOPIC_PATTERNS.each do |topic, patterns|
      if patterns.any? { |pattern| text.match?(pattern) }
        detected << topic
      end
    end

    detected.size == 1 ? detected.first : :general
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