# lib/prompts/instructions.rb

module Prompts
  class Instructions
    def build
      <<~TEXT
        Rules:

        - Preserve existing architecture.
        - Follow Rails conventions.
        - Avoid unnecessary changes.
        - If a requested change affects multiple files, keep them consistent.
        - Only reference information present in the supplied context.
      TEXT
    end
  end
end