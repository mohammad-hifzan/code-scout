module ProjectHelper
  def fixture_project
    ENV.fetch(
      "FIXTURE_PROJECT",
      "/home/mohammad-hifzan/Projects/personal/shop-station"
    )
  end
end

RSpec.configure do |config|
  config.include ProjectHelper
end