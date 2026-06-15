# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

class ReferenceFinder
  SEARCH_PATHS = [
    "app/**/*.rb",
    "app/**/*.erb"
  ].freeze

  def initialize(project_path)
    @project_path = project_path
  end

  def find(constant_name)
    search_terms = [
      constant_name,
      constant_name.underscore
    ].uniq

    files = SEARCH_PATHS.flat_map do |pattern|
      Dir.glob(File.join(@project_path, pattern))
    end

    files.select do |file|
      content = File.read(file)

      search_terms.any? do |term|
        content.include?(term)
      end
    rescue StandardError
      false
    end
  end
end