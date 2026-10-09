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

  DEBUG_PATTERNS = [
    /\bfails?\b/i,
    /\bisn't\b/i
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
      /\b\w+\s+(?:job|worker)(?:s)?\s+(?:is|are|failing|failed|fail|fails|broken|error|failure)\b/i,
      /\b(?:the\s+)?\w+\s+(?:job|worker)(?:s)?\s+failing\b/i,
      /\b(?:job|worker)s?\s+behavior\b/i,
      /\b(?:the\s+)?(?:job|worker)s?\s+(?:that|to|for)\b/i
    ],
    mailer: [
      /\b[A-Za-z0-9_:]*mailer(s)?\b/i,
      /\b(?:email|mailer)\s+template(s)?\b/i,
      /\bemail\s+delivery\b/i,
      /\bdeliver\s+mail\b/i,
      /\b(?:deliver_later|deliver_now)\b/i,
      /\baction_?mailer\b/i,
      /\bemails?\s+(?:being\s+)?sent\b/i,
      /\bemails?\s+notification(s)?\b/i
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

  ASSOCIATION_STOP_WORDS = %w[
    the
    a
    an
    this
    that
    these
    those
    my
    our
    your
    their
    its
    on
    in
    for
    with
    between
    to
    from
    at
    by
    of
    and
    or
    is
    are
    model
    record
    entity
    table
    new
    old
    current
    existing
    belongs_to
    has_many
    has_one
    has_and_belongs_to_many
    association
    associations
    relationship
    relationships
  ].freeze

  SERVICE_ACTION_STOP_WORDS = %w[
    the
    a
    an
    this
    that
    these
    those
    my
    our
    your
    their
    its
    for
    to
    of
    in
    on
    at
    by
    with
    and
    or
    is
    are
    used
    service
    services
    object
    objects
    model
    record
    entity
    handle
    handles
    handl
    manage
    manages
    process
    processes
    perform
    performs
    provide
    provides
    execute
    executes
    run
    runs
    do
    does
  ].freeze

  CONCERN_STOP_WORDS = %w[
    the
    a
    an
    this
    that
    these
    those
    my
    our
    your
    their
    its
    model
    models
    controller
    controllers
    active_support
    activesupport
    concern
    concerns
    mixin
    mixins
  ].freeze

  def initialize(models: [])
    @models = models || []
  end

  def analyze(request, models: nil)
    models_list = models || @models
    detected_topics = detect_topics(request)
    topic = detected_topics.size == 1 ? detected_topics.first : :general

    result = {
      action: detect_action(request),
      entity: detect_entity(request, models_list),
      topic: topic
    }

    result[:topics] = detected_topics if detected_topics.size > 1

    has_topic = ->(t) { topic == t || (result[:topics] && result[:topics].include?(t)) }

    result[:association] = detect_association(request, result[:entity]) if has_topic.call(:association)
    if has_topic.call(:service)
      service_action = detect_service_action(request, result[:entity])
      result[:service_action] = service_action if service_action
    end
    if has_topic.call(:concern)
      concern_name = detect_concern_name(request, result[:entity])
      result[:concern_name] = concern_name if concern_name
    end
    result
  end

  private

  def detect_action(request)
    text = request.downcase

    # Debug signals (e.g. "NoMethodError", "debug", "broken", "failing", "bug", "exception")
    return :debug if DEBUG_KEYWORDS.any? { |k| text.include?(k) }
    return :debug if DEBUG_PATTERNS.any? { |pattern| text.match?(pattern) }

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
    # Prefer exact non-concern model matches over concerns mapped as models
    direct_matches = []
    tokens.each do |token|
      clean_token = token.sub(/'s\z/i, "").sub(/'\z/, "")
      downcased = clean_token.downcase

      matched = lookup[downcased] || lookup[singularize(downcased)]
      direct_matches << matched if matched
    end

    if direct_matches.any?
      real_model = direct_matches.find { |m| !m.start_with?("Concerns::") }
      return real_model if real_model
      return direct_matches.first
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

        if suffix == "service"
          matched = resolve_compound_service(token, base, lookup)
          return matched if matched
        end
      end

      singular = singularize(downcased)
      if singular != downcased && singular.end_with?(suffix) && singular.length > suffix.length
        base = singular[0...-suffix.length].sub(/_\z/, "")
        matched = lookup[base] || lookup[singularize(base)]
        return matched if matched

        if suffix == "service"
          matched = resolve_compound_service(token, base, lookup)
          return matched if matched
        end
      end
    end

    nil
  end

  def resolve_compound_service(token, base, lookup)
    matching_keys = lookup.keys.select { |k| base.start_with?(k) }
    matching_keys.sort_by! { |k| -k.length }

    matching_keys.each do |k|
      next unless token[0...k.length].downcase == k

      boundary_char = token[k.length]
      return lookup[k] if boundary_char =~ /[A-Z_]/
    end

    nil
  end

  def detect_topic(request)
    topics = detect_topics(request)
    topics.size == 1 ? topics.first : :general
  end

  def detect_topics(request)
    text = request.downcase

    detected = []
    TOPIC_PATTERNS.each do |topic, patterns|
      if patterns.any? { |pattern| text.match?(pattern) }
        detected << topic
      end
    end

    detected.uniq
  end

  def detect_association(request, entity)
    text = request.to_s

    # 1. Macro-based: e.g. "belongs_to account", "has_many :posts"
    if (m = text.match(/\b(?:belongs_to|has_many|has_one|has_and_belongs_to_many)\s+:?([a-z0-9_]+)\b/i))
      candidate = m[1].downcase
      return candidate unless ASSOCIATION_STOP_WORDS.include?(candidate)
    end

    # 2. "with" preposition: e.g. "association with :posts", "relationship with posts"
    if (m = text.match(/\b(?:association|relationship)s?\s+with\s+:?([a-z0-9_]+)\b/i))
      candidate = m[1].downcase
      return candidate unless ASSOCIATION_STOP_WORDS.include?(candidate) || candidate == entity&.downcase
    end

    # 3. Preceding token: e.g. "posts association", "User's posts relationship", "the posts association"
    if (m = text.match(/\b:?([a-z0-9_]+)(?:'s|')?\s+(?:association|relationship)s?\b/i))
      candidate = m[1].downcase
      return candidate unless ASSOCIATION_STOP_WORDS.include?(candidate) || candidate == entity&.downcase
    end

    # 4. Following token: e.g. "association posts", "relationship :posts"
    if (m = text.match(/\b(?:association|relationship)s?\s+:?([a-z0-9_]+)\b/i))
      candidate = m[1].downcase
      return candidate unless ASSOCIATION_STOP_WORDS.include?(candidate) || candidate == entity&.downcase
    end

    nil
  end

  def detect_service_action(request, entity)
    text = request.to_s

    # 1. "service that/which/to <action>" e.g. "service that imports Users" -> "import"
    if (m = text.match(/\bservice\s+(?:object\s+)?(?:that|which|to)\s+([a-z0-9_]+)\b/i))
      candidate = singularize(m[1].downcase)
      return candidate unless SERVICE_ACTION_STOP_WORDS.include?(candidate) || candidate == entity&.downcase
    end

    # 2. "service used for / for ... <action>" e.g. "service used for User registration" -> "registration"
    if (m = text.match(/\bservice\s+(?:object\s+)?(?:used\s+for|for)\s+(?:the\s+)?(?:[a-z0-9_:]+(?:'s|')?\s+)*([a-z0-9_]+)\b/i))
      candidate = singularize(m[1].downcase)
      return candidate unless SERVICE_ACTION_STOP_WORDS.include?(candidate) || candidate == entity&.downcase
    end

    nil
  end

  def detect_concern_name(request, entity)
    text = request.to_s

    # Matches explicit concern requests such as:
    # "Change the Auditable concern for User."
    # "Change the Searchable concern for User."
    if (m = text.match(/\b(?:change|update|modify|refactor)\s+the\s+([A-Za-z0-9_:]+)\s+concern\s+for\b/i))
      candidate = m[1]
      return candidate unless CONCERN_STOP_WORDS.include?(candidate.downcase) || candidate.downcase == entity&.downcase
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