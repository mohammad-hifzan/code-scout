require 'parser/current'
require 'active_support/core_ext/string/inflections'

class RouteMapper
  def initialize(project_path)
    @project_path = project_path
  end

  def map
    routes_file = File.join(@project_path, "config/routes.rb")
    return [] unless File.exist?(routes_file)

    source = File.read(routes_file)
    return [] if source.strip.empty?

    node = Parser::CurrentRuby.parse(source)
    return [] unless node

    visitor = RouteVisitor.new
    visitor.process(node)
    visitor.routes
  end

  class RouteVisitor < Parser::AST::Processor
    attr_reader :routes

    def initialize
      @routes = []
      @namespace_stack = []
    end

    def on_send(node)
      receiver, method_name, *args = *node

      case method_name
      when :resources
        extract_resource(args, plural: true)
      when :resource
        extract_resource(args, plural: false)
      when :root
        extract_root(args)
      when :get, :post, :patch, :put, :delete
        extract_custom_route(node)
      when :devise_for
        extract_devise_routes(args)
      end

      super(node)
    end

    def on_block(node)
      send_node, _args, body = *node
      receiver, method_name, *block_args = *send_node

      if method_name == :namespace
        namespace = block_args.first.children.first.to_s
        @namespace_stack.push(namespace.camelize)
        process(body)
        @namespace_stack.pop
      else
        super(node)
      end
    end

    private

    def extract_resource(args, plural:)
      resource_name = args.first.children.first.to_s
      controller_name = plural ? resource_name.camelize : resource_name.camelize.pluralize
      @routes << {
        type: "resource",
        resource: resource_name,
        controller: full_controller_name("#{controller_name}Controller")
      }
    end

    def extract_root(args)
      path = args.first.children.first
      controller, action = path.split('#')
      @routes << {
        type: "root",
        controller: full_controller_name("#{controller.camelize}Controller"),
        action: action
      }
    end

    def extract_custom_route(node)
      _receiver, method_name, *args = *node

      # Handles `get 'path' => 'controller#action'`
      if args.first.type == :hash
        pair = args.first.children.first
        path = pair.children.first.children.first
        controller, action = pair.children.last.children.first.split('#')
        @routes << {
          type: "custom",
          verb: method_name.to_s.upcase,
          path: path,
          controller: full_controller_name("#{controller.camelize}Controller"),
          action: action
        }
        return
      end
      
      path_node = args.first
      path = path_node.type == :str ? path_node.children.first : path_node.loc.expression.source

      options = args.last
      if options.type == :hash # Handles `get 'path', to: 'controller#action'`
        to_option = options.children.find { |pair| pair.children.first.children.first == :to }
        if to_option
          controller, action = to_option.children.last.children.first.split('#')
          @routes << {
            type: "custom",
            verb: method_name.to_s.upcase,
            path: path,
            controller: full_controller_name("#{controller.camelize}Controller"),
            action: action
          }
        end
      elsif options.type == :str # "rater#create" - handles get 'path', 'controller#action'
        controller, action = options.children.first.split('#')
        @routes << {
          type: "custom",
          verb: method_name.to_s.upcase,
          path: path,
          controller: full_controller_name("#{controller.camelize}Controller"),
          action: action
        }
      end
    end
    
    def extract_devise_routes(args)
      # This is a simplified version. A real implementation would need to
      # understand Devise's conventions better.
      resource = args.first.children.first
      return unless resource.is_a?(Symbol)
      
      %w[
        SessionsController
        RegistrationsController
        PasswordsController
        ConfirmationsController
        UnlocksController
        OmniauthCallbacksController
      ].map do |controller|
        @routes << {
          type: "devise",
          controller: controller
        }
      end
    end

    def full_controller_name(name)
      (@namespace_stack + [name]).join('::')
    end
  end
end
