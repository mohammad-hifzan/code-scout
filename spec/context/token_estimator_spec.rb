require "spec_helper"
require "tempfile"

require_relative "../../lib/context/token_estimator"

RSpec.describe TokenEstimator do
  subject(:estimator) { described_class.new }

  it "adds estimated_tokens to each file" do
    file = Tempfile.new(["shop", ".rb"])
    file.write("class Shop\nend")
    file.close

    result = estimator.estimate(
      [
        {
          path: file.path,
          category: :primary
        }
      ]
    )

    expect(result.first[:estimated_tokens]).to be > 0

    file.unlink
  end
end