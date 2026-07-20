require "spec_helper"
require_relative "../../lib/nlp/request_analyzer"

RSpec.describe RequestAnalyzer do
  subject(:analyzer) { described_class.new }

  it "detects edit requests" do
    expect(
      analyzer.analyze("Add slug validation to Shop")
    ).to eq(
      action: :edit,
      entity: "Shop"
    )
  end

  it "detects explain requests" do
    expect(
      analyzer.analyze("Explain Shop")
    ).to eq(
      action: :explain,
      entity: "Shop"
    )
  end

  it "detects debug requests" do
    expect(
      analyzer.analyze("Debug Shop")
    ).to eq(
      action: :debug,
      entity: "Shop"
    )
  end
end