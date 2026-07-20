require "spec_helper"

require_relative "../../lib/context/context_pruner"

RSpec.describe ContextPruner do
  subject(:pruner) { described_class.new }

  let(:items) do
    [
      {
        path: "a.rb",
        estimated_tokens: 1000
      },
      {
        path: "b.rb",
        estimated_tokens: 900
      },
      {
        path: "c.rb",
        estimated_tokens: 1200
      }
    ]
  end

  it "keeps files within the token budget" do
    result = pruner.prune(
      items,
      max_tokens: 2000
    )

    expect(result[:files].map { |f| f[:path] })
      .to eq(%w[a.rb b.rb])

    expect(result[:total_tokens]).to eq(1900)
  end
end