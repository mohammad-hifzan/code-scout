require_relative '../nlp/request_analyzer'
module Pipeline
  class Pipeline
    def initialize(
      request_analyzer: RequestAnalyzer.new
    )
      @request_analyzer = request_analyzer
    end

    def run(request)
      @request_analyzer.analyze(request)
    end
  end
end