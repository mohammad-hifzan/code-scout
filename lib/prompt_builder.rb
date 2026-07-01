# lib/prompt_builder.rb

require_relative "prompts/header"
require_relative "prompts/instructions"
require_relative "prompts/context_section"
require_relative "prompts/task"

class PromptBuilder
  def initialize(files)
    @files = files
  end

  def build(task:)
    [
      Prompts::Header.new.build,
      Prompts::Instructions.new.build,
      Prompts::ContextSection.new.build(@files),
      Prompts::Task.new.build(task)
    ].join("\n\n")
  end
end