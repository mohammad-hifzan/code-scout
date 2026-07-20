require "spec_helper"
require "tempfile"
require_relative "../../lib/context/file_loader"

RSpec.describe FileLoader do
  subject(:loader) { described_class.new }

  it "loads file contents" do
    file = Tempfile.new(["shop", ".rb"])
    file.write("class Shop\nend")
    file.close

    result = loader.load_files(
      [
        {
          path: file.path,
          category: :primary
        }
      ]
    )

    expect(result.first[:content]).to include("class Shop")

    file.unlink
  end
end