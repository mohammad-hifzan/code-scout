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

  def analyze(request)
    {
      action: detect_action(request),
      entity: detect_entity(request)
    }
  end

  private

  def detect_action(request)
    text = request.downcase

    return :debug if DEBUG_KEYWORDS.any? { |k| text.include?(k) }

    return :explain if EXPLAIN_KEYWORDS.any? { |k| text.include?(k) }

    :edit
  end

  def detect_entity(request)
    request.scan(/\b[A-Z][A-Za-z0-9_:]+\b/).first
  end
end