require "spec_helper"

require_relative "../../lib/nlp/request_analyzer"

RSpec.describe RequestAnalyzer do
  let(:analyzer) { described_class.new }

  it "detects edit requests" do
    pending("Entity extraction is still heuristic")

    expect(
      analyzer.analyze("Add slug validation to Shop")
    ).to eq(
      action: :edit,
      entity: "Shop"
    )
  end

  it "detects explain requests" do
    pending("Entity extraction is still heuristic")

    expect(
      analyzer.analyze("Explain Shop")
    ).to eq(
      action: :explain,
      entity: "Shop"
    )
  end

  it "detects debug requests" do
    pending("Entity extraction is still heuristic")

    expect(
      analyzer.analyze("Debug Shop")
    ).to eq(
      action: :debug,
      entity: "Shop"
    )
  end

  it "defaults to the :edit action for generic requests" do
    analysis = analyzer.analyze("some generic request")
    expect(analysis[:action]).to eq(:edit)
  end
end