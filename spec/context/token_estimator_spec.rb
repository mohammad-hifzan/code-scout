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

  it "returns 0 tokens for an empty file" do
    file = Tempfile.new("empty.rb")
    file.close # File is created but empty

    result = estimator.estimate([{ path: file.path }])
    expect(result.first[:estimated_tokens]).to eq(0)
    file.unlink
  end

  it "returns 0 tokens for a nonexistent file" do
    result = estimator.estimate([{ path: "/path/to/nonexistent_file.rb" }])
    expect(result.first[:estimated_tokens]).to eq(0)
  end

  it "calculates tokens exactly for content that is a multiple of 4 characters" do
    file = Tempfile.new("multiple_of_4.rb")
    file.write("abcdABCD") # 8 characters
    file.close

    result = estimator.estimate([{ path: file.path }])
    expect(result.first[:estimated_tokens]).to eq(2) # 8 / 4 = 2
    file.unlink
  end

  it "rounds up token count for content not a multiple of 4 characters" do
    file = Tempfile.new("not_multiple_of_4.rb")
    file.write("abcde") # 5 characters
    file.close

    result = estimator.estimate([{ path: file.path }])
    expect(result.first[:estimated_tokens]).to eq(2) # (5 / 4).ceil = 1.25.ceil = 2
    file.unlink
  end

  it "handles multiple files correctly" do
    file1 = Tempfile.new("file1.rb")
    file1.write("1234") # 4 chars = 1 token
    file1.close

    file2 = Tempfile.new("file2.rb")
    file2.write("1234567") # 7 chars = 2 tokens
    file2.close

    result = estimator.estimate([
                                  { path: file1.path, type: :model },
                                  { path: file2.path, type: :controller }
                                ])

    expect(result.first[:estimated_tokens]).to eq(1)
    expect(result.last[:estimated_tokens]).to eq(2)
    file1.unlink
    file2.unlink
  end

  it "preserves all original item fields" do
    file = Tempfile.new("preserve.rb")
    file.write("content")
    file.close

    original_item = { path: file.path, category: :primary, source: "user" }
    result = estimator.estimate([original_item])

    expect(result.first[:path]).to eq(file.path)
    expect(result.first[:category]).to eq(:primary)
    expect(result.first[:source]).to eq("user")
    expect(result.first).to have_key(:estimated_tokens)
    file.unlink
  end

  it "returns an empty array when given an empty input array" do
    expect(estimator.estimate([])).to eq([])
  end

  it "raises an error for an item with a missing :path key" do
    expect { estimator.estimate([{ category: :primary }]) }
      .to raise_error(TypeError) # File.exist?(nil) raises TypeError
  end

  it "raises an error for an item with a nil :path value" do
    expect { estimator.estimate([{ path: nil, category: :primary }]) }
      .to raise_error(TypeError) # File.exist?(nil) raises TypeError
  end

  it "correctly estimates tokens for Unicode content" do
    file = Tempfile.new(["unicode", ".rb"], encoding: 'UTF-8')
    # "你好世界" - 4 characters, 12 bytes in UTF-8
    # Ruby's String#size counts characters for UTF-8 encoded strings
    file.write("你好世界") # 4 characters
    file.close

    result = estimator.estimate([{ path: file.path }])
    expect(result.first[:estimated_tokens]).to eq(1) # (4 / 4).ceil = 1
    file.unlink
  end
end