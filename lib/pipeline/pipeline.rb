require_relative '../nlp/request_analyzer'
module Pipeline
  class Pipeline
    def initialize(project_path)
      @project_path = project_path
    end

    def run(request)
      analysis = RequestAnalyzer.new.analyze(request)

      rule =
        RuleSelector.new.select(
          analysis[:action]
        )

      project_map =
        ProjectMapper
          .new(@project_path)
          .map

      index =
        ProjectIndex.new(
          project_map,
          @project_path
        )

      context =
        ContextEngine
          .new(index)
          .build(
            analysis[:entity],
            rule: rule
          )

      ranked =
        context[:ranked]

      estimated =
        TokenEstimator
          .new
          .estimate(ranked)

      pruned =
        ContextPruner
          .new
          .prune(
            estimated,
            max_tokens: 3000
          )

      files =
        FileLoader
          .new
          .load_files(
            pruned[:files]
          )

      PromptBuilder.new.build(
        files: files,
        request: request
      )
    end
  end
end