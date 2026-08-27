require "parser/current"
require "active_support/core_ext/object/blank"

class ModelAnalyzer
  def analyze(path)
    source = File.read(path)

    return empty_result(path) if source.blank?

    node = Parser::CurrentRuby.parse(source)
    return empty_result(path) unless node

    visitor = ModelVisitor.new
    visitor.process(node)

    {
      model: model_name(path),
      associations: visitor.associations,
      validations: visitor.validations,
      callbacks: visitor.callbacks,
      scopes: visitor.scopes,
      enums: visitor.enums,
      includes: visitor.includes,
      extends: visitor.extends
    }
  end

  private

  def model_name(path)
    File.basename(path, ".rb").camelize
  end

  def empty_result(path)
    {
      model: model_name(path),
      associations: {
        belongs_to: [],
        has_many: [],
        has_one: []
      },
      validations: [],
      callbacks: [],
      scopes: [],
      enums: [],
      includes: [],
      extends: []
    }
  end

  class ModelVisitor < Parser::AST::Processor
    attr_reader :associations,
                :validations,
                :callbacks,
                :scopes,
                :enums,
                :includes,
                :extends

    def initialize
      @associations = {
        belongs_to: [],
        has_many: [],
        has_one: []
      }

      @validations = []
      @callbacks = []
      @scopes = []
      @enums = []
      @includes = []
      @extends = []
    end

    def on_send(node)
      receiver, method_name, *args = *node

      if receiver.nil?
        case method_name
        when :belongs_to, :has_many, :has_one
          add_association(method_name, args)

        when :validates
          add_validations(args)

        when /^before_/, /^after_/, /^around_/
          add_callback(args)

        when :scope, :pg_search_scope
          add_to_list(@scopes, args)

        when :enum
          add_to_list(@enums, args)

        when :include
          add_module(@includes, args)

        when :extend
          add_module(@extends, args)
        end
      end

      super
    end

    private

    def add_association(type, args)
      name_node = args.find { |arg| arg.type == :sym }
      return unless name_node

      name = name_node.children.first.to_s
      options = {}
      options_node = args.find { |arg| arg.type == :hash }
      if options_node
        options_node.children.each do |pair|
          key_node, value_node = *pair
          if key_node.type == :sym
            key = key_node.children.first
            value = extract_string_or_symbol_value(value_node)
            next unless value

            case key
            when :class_name
              options[:class_name] = value
            when :through
              options[:through] = value
            when :source
              options[:source] = value
            end
          end
        end
      end
      association_data = { name: name }
      association_data[:class_name] = options[:class_name] if options[:class_name]
      association_data[:through] = options[:through] if options[:through]
      association_data[:source] = options[:source] if options[:source]
      @associations[type] << association_data
    end

    def add_validations(args)
      args.each do |arg|
        next unless arg.type == :sym

        @validations << arg.children.first.to_s
      end
    end

    def add_callback(args)
      name = first_symbol(args)
      @callbacks << name if name
    end

    def add_to_list(list, args)
      name = first_symbol(args)
      list << name if name
    end

    def add_module(list, args)
      return if args.empty?

      node = args.first
      name = node.loc.expression.source

      list << name if name
    end

    def first_symbol(args)
      arg = args.find { |argument| argument.type == :sym }
      arg&.children&.first&.to_s
    end

    def extract_string_or_symbol_value(node)
      return node.children.first if node.type == :str
      return node.children.first.to_s if node.type == :sym
      nil
    end
  end
end