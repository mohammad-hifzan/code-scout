# lib/prompt_builder.rb

require_relative "header"
require_relative "instructions"
require_relative "context_section"
require_relative "task"

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