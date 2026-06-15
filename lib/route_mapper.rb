# lib/route_mapper.rb

class RouteMapper
  def initialize(project_path)
    @project_path = project_path
  end

  def map
    routes_file =
      File.join(project_path, "config/routes.rb")

    return [] unless File.exist?(routes_file)

    content = File.read(routes_file)

    resources(content) + custom_routes(content)
  end

  private

  attr_reader :project_path

  def resources(content)
    content.scan(/resources\s+:([a-z_]+)/)
           .flatten
           .map do |resource|
      {
        type: "resource",
        name: resource
      }
    end
  end

  def custom_routes(content)
    content.scan(
      /(get|post|patch|put|delete)\s+["']([^"']+)["']/
    ).map do |verb, path|
      {
        verb: verb.upcase,
        path: path
      }
    end
  end
end