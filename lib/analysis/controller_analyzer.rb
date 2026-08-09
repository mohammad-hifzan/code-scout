require "parser/current"
require "active_support/core_ext/string/inflections"
require 'active_support/core_ext/object/blank'

class ControllerAnalyzer
  def analyze(path)
    source = File.read(path)
    return empty_result(path) if source.blank?

    node = Parser::CurrentRuby.parse(source)
    return empty_result(path) unless node

    visitor = ControllerVisitor.new
    visitor.process(node)

    {
      controller: controller_name_from_path(path),
      modules: visitor.modules,
      callbacks: visitor.callbacks,
      actions: visitor.actions
    }
  end

  private

  def controller_name_from_path(path)
    File.basename(path, ".rb")
  end

  def empty_result(path)
    {
      controller: controller_name_from_path(path),
      modules: [],
      callbacks: { before: [], after: [], around: [] },
      actions: []
    }
  end

  class ControllerVisitor < Parser::AST::Processor
    attr_reader :modules, :callbacks, :actions

    def initialize
      @modules = []
      @callbacks = { before: [], after: [], around: [] }
      @actions = []
      @current_visibility = :public
      @current_action = nil
      @ignored_constants = ['Current']
    end

    def on_class(node)
      # In the future, we could extract the class name here and compare with the filename
      super
    end

    def on_def(node)
      method_name = node.children[0].to_s
      
      if @current_visibility == :public
        @current_action = {
          name: method_name,
          authorizes: false,
          models: []
        }
        
        super
        
        @actions << @current_action
        @current_action = nil
      end
    end

    def on_send(node)
      receiver, method_name, *args = *node

      # Top-level declarations in the class body
      if @current_action.nil? && receiver.nil?
        case method_name
        when :include
          @modules << constant_to_string(args.first)
        when :before_action
          add_callback(:before, args)
        when :after_action
          add_callback(:after, args)
        when :around_action
          add_callback(:around, args)
        when :private
          @current_visibility = :private
        when :protected
          @current_visibility = :protected
        when :public
          @current_visibility = :public
        end
      end

      # Inside an action
      if @current_action
        if method_name == :authorize
          @current_action[:authorizes] = true
        end

        if receiver && receiver.type == :const
          model_name = constant_to_string(receiver)
          if model_name && !@ignored_constants.include?(model_name)
            @current_action[:models] << model_name unless @current_action[:models].include?(model_name)
          end
        end
      end

      super
    end
    
    def on_ivasgn(node)
      if @current_action
        ivar_name = node.children[0].to_s
        # @post -> Post
        model_from_ivar = ivar_name.delete_prefix('@').singularize.camelize
        
        # Check if the value being assigned is a model instantiation
        value_node = node.children[1]
        model_from_assignment = extract_model_from_assignment(value_node)

        model = model_from_assignment || model_from_ivar
        
        @current_action[:models] << model unless @current_action[:models].include?(model)
      end
      super
    end

    private

    def add_callback(type, args)
      return if args.empty?
      
      callback_name = symbol_from_arg(args.first)
      @callbacks[type] << callback_name if callback_name
    end

    def symbol_from_arg(arg)
      return nil unless arg
      if arg.type == :sym
        arg.children.first.to_s
      elsif arg.type == :str
        arg.children.first.to_s
      else
        nil
      end
    end

    def constant_to_string(node)
      return nil unless node && node.type == :const
      
      namespace, name = *node
      if namespace
        "#{constant_to_string(namespace)}::#{name}"
      else
        name.to_s
      end
    end
    
    def extract_model_from_assignment(node)
      return nil unless node && node.type == :send
      
      receiver, method_name, _args = *node
      return nil unless receiver && receiver.type == :const
      
      constant_to_string(receiver)
    end
  end
end