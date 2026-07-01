module Prompts
  class Header
    def build
      <<~TEXT
        You are an expert Ruby on Rails software engineer.

        Use the provided project context to complete the requested task.
        Do not assume files that are not present in the context.
      TEXT
    end
  end
end