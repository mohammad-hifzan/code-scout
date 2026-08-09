# lib/prompt_builder.rb

require_relative "header"
require_relative "instructions"
require_relative "context_section"
require_relative "task"
# puts instance_method(:build).parameters.inspect
class PromptBuilder
  def build(request:, files:)
    [
      Prompts::Header.new.build,
      Prompts::Instructions.new.build,
      Prompts::ContextSection.new.build(files),
      Prompts::Task.new.build(request)
    ].join("\n\n")
  end
end