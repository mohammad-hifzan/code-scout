# lib/prompts/context_section.rb

module Prompts
  class ContextSection
    def build(files)
      sections = files.map do |file|
        <<~TEXT
          ## #{file[:category].to_s.upcase}

          File: #{file[:path]}

          ```#{language(file[:path])}
          #{file[:content]}
          ```
        TEXT
      end

      sections.join("\n")
    end

    private

    def language(path)
      case File.extname(path)
      when ".rb"
        "ruby"
      when ".erb"
        "erb"
      when ".js"
        "javascript"
      when ".css"
        "css"
      when ".yml", ".yaml"
        "yaml"
      when ".json"
        "json"
      when ".md"
        "markdown"
      when ".sql"
        "sql"
      else
        ""
      end
    end
  end
end