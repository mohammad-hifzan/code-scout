require_relative '../nlp/request_analyzer'
require_relative '../nlp/rule_selector'
require_relative '../indexing/project_mapper'
require_relative '../indexing/project_index'
require_relative '../context/context_engine'
require_relative '../context/token_estimator'
require_relative '../context/context_pruner'
require_relative '../context/file_loader'
require_relative '../prompts/prompt_builder'

module Pipeline
  class Pipeline
    def initialize(project_path)
      @project_path = project_path
    end

    def run(request)
      project_map =
        ProjectMapper
          .new(@project_path)
          .map

      models = project_map[:models]&.keys || []

      analysis =
        RequestAnalyzer
          .new(models: models)
          .analyze(request)

      rule =
        RuleSelector.new.select(
          analysis[:action]
        )

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

      return unless context

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