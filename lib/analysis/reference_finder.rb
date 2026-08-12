# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "parser/current"

class ReferenceFinder
  SEARCH_PATHS = [
    "app/**/*.rb",
    "app/**/*.erb"
  ].freeze

  def initialize(project_path)
    @project_path = project_path
  end

  def find(constant_name)
    return [] unless File.directory?(@project_path)

    SEARCH_PATHS.flat_map do |pattern|
      Dir.glob(File.join(@project_path, pattern))
    end
      .uniq
      .filter_map do |file|
        begin
          content = File.read(file)
          ruby = extract_ruby(file, content)
          file if references_constant?(ruby, constant_name)
        rescue StandardError
          nil
        end
      end
  end

  private

  def extract_ruby(file, content)
    return content unless File.extname(file) == ".erb"

    content.scan(/<%[=-]?\s*(.*?)\s*%>/m).flatten.join("\n")
  end

  def references_constant?(code, constant_name)
    return false if code.to_s.strip.empty?

    ast = parse_ast(code)
    return false unless ast

    constant_reference?(ast, constant_name)
  end

  def parse_ast(code)
    buffer = Parser::Source::Buffer.new("(string)")
    buffer.source = code
    Parser::CurrentRuby.new.parse(buffer)
  rescue Parser::SyntaxError
    nil
  end

  def constant_reference?(node, constant_name)
    return false unless node

    return false unless node.is_a?(Parser::AST::Node)

    if node.type == :class || node.type == :module
      const_node = node.children.first
      return true if exact_constant_name?(const_node, constant_name)
    end

    return true if node.type == :const && exact_constant_name?(node, constant_name)

    node.children.any? do |child|
      constant_reference?(child, constant_name)
    end
  end

  def exact_constant_name?(node, target_name)
    return false unless node.is_a?(Parser::AST::Node)
    return false unless node.type == :const

    full_constant_name(node) == target_name
  end

  def full_constant_name(node)
    return nil unless node.is_a?(Parser::AST::Node)
    return nil unless node.type == :const

    namespace_node, const_name = node.children

    if namespace_node && namespace_node.type == :cbase
      const_name.to_s
    elsif namespace_node && namespace_node.type == :const
      namespace = full_constant_name(namespace_node)
      namespace ? "#{namespace}::#{const_name}" : const_name.to_s
    else
      const_name.to_s
    end
  end
end
