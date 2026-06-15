require "bundler"
require "yaml"
require "erb"

class Scanner
  def initialize(project_path)
    @project_path = project_path
  end

  def scan
    {
      rails_version: rails_version,
      gems: installed_gems,
      database: database_adapter
    }
  end

  private

  attr_reader :project_path

  def rails_version
    lockfile =
      Bundler::LockfileParser.new(
        Bundler.read_file(
          File.join(project_path, "Gemfile.lock")
        )
      )

    rails_spec =
      lockfile.specs.find do |spec|
        spec.name == "rails"
      end

    rails_spec&.version&.to_s
  end

  def installed_gems
    lockfile =
      Bundler::LockfileParser.new(
        Bundler.read_file(
          File.join(project_path, "Gemfile.lock")
        )
      )

    lockfile.specs.map(&:name)
  end

  def database_adapter
    db_file =
      File.join(project_path, "config/database.yml")

    return nil unless File.exist?(db_file)

    content = ERB.new(File.read(db_file)).result

    config = YAML.safe_load(content, aliases: true)

    config.each_value do |environment|
      next unless environment.is_a?(Hash)

      return environment["adapter"] if environment["adapter"]
    end

    nil
  end

end
