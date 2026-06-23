class RouteMapper
  def initialize(project_path)
    @project_path = project_path
  end

  def map
    routes_file =
      File.join(project_path, "config/routes.rb")

    return [] unless File.exist?(routes_file)

    content = File.read(routes_file)

    resources(content) +
      singular_resources(content) +
      root_routes(content) +
      custom_routes(content) +
      namespaces(content) +
      devise_routes(content)
  end

  private

  attr_reader :project_path

  def resources(content)
    content.scan(/resources\s+:([a-z_]+)/)
           .flatten
           .map do |resource|
      {
        type: "resource",
        resource: resource,
        controller: "#{resource.camelize}Controller"
      }
    end
  end

  def singular_resources(content)
    content.scan(/resource\s+:([a-z_]+)/)
           .flatten
           .map do |resource|
      {
        type: "resource",
        resource: resource,
        controller: "#{resource.camelize.pluralize}Controller"
      }
    end
  end

  def root_routes(content)
    content.scan(/root\s+["']([^#]+)#([^"']+)["']/)
           .map do |controller, action|
      {
        type: "root",
        controller: "#{controller.camelize}Controller",
        action: action
      }
    end
  end

  def custom_routes(content)
    routes = []

    # post "/rate" => "rater#create"
    content.scan(
      /(get|post|patch|put|delete)\s+["']([^"']+)["']\s*=>\s*["']([^#]+)#([^"']+)["']/
    ).each do |verb, path, controller, action|
      routes << {
        type: "custom",
        verb: verb.upcase,
        path: path,
        controller: "#{controller.camelize}Controller",
        action: action
      }
    end

    # get "search", to: "search#item"
    content.scan(
      /(get|post|patch|put|delete)\s+["']([^"']+)["'].*?["']([^#]+)#([^"']+)["']/
    ).each do |verb, path, controller, action|
      routes << {
        type: "custom",
        verb: verb.upcase,
        path: path,
        controller: "#{controller.camelize}Controller",
        action: action
      }
    end

    routes.uniq
  end

  def namespaces(content)
    routes = []

    content.scan(
      /namespace\s+:([a-z_]+)\s+do(.*?)end/m
    ).each do |namespace_name, block|
      block.scan(/resources\s+:([a-z_]+)/)
           .flatten
           .each do |resource|

        routes << {
          type: "resource",
          resource: resource,
          controller:
            "#{namespace_name.camelize}::#{resource.camelize}Controller"
        }
      end
    end

    routes
  end

  def devise_routes(content)
    return [] unless content.match?(/devise_for\s+:users/)

    %w[
      SessionsController
      RegistrationsController
      PasswordsController
      ConfirmationsController
      UnlocksController
      OmniauthCallbacksController
    ].map do |controller|
      {
        type: "devise",
        controller: controller
      }
    end
  end
end