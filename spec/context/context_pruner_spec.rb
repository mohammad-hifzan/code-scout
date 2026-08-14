require "spec_helper"
require_relative "../../lib/context/context_pruner"

RSpec.describe ContextPruner do
  subject(:pruner) { described_class.new }

  let(:item1) { { path: "item1.rb", estimated_tokens: 100 } }
  let(:item2) { { path: "item2.rb", estimated_tokens: 200 } }
  let(:item3) { { path: "item3.rb", estimated_tokens: 300 } }
  let(:items) { [item1, item2, item3] }

  it "selects items greedily until the budget is full" do
    result = pruner.prune(items, max_tokens: 350)
    expect(result[:files].map { |f| f[:path] }).to eq(["item1.rb", "item2.rb"])
    expect(result[:total_tokens]).to eq(300)
  end

  it "preserves the original input order" do
    shuffled_items = [item2, item1, item3]
    result = pruner.prune(shuffled_items, max_tokens: 350)
    expect(result[:files].map { |f| f[:path] }).to eq(["item2.rb", "item1.rb"])
  end

  it "skips an item that exceeds the budget and continues to the next" do
    items = [item1, item3, item2] # 100, 300, 200
    result = pruner.prune(items, max_tokens: 350)
    # It should take item1 (100), skip item3 (300) because 100+300 > 350,
    # and then take item2 (200) because 100+200 <= 350.
    expect(result[:files].map { |f| f[:path] }).to eq(["item1.rb", "item2.rb"])
    expect(result[:total_tokens]).to eq(300)
  end

  it "includes all items if they all fit within the budget" do
    result = pruner.prune(items, max_tokens: 1000)
    expect(result[:files].map { |f| f[:path] }).to eq(["item1.rb", "item2.rb", "item3.rb"])
    expect(result[:total_tokens]).to eq(600)
  end

  it "selects no items if the first item already exceeds the budget" do
    result = pruner.prune(items, max_tokens: 50)
    expect(result[:files]).to be_empty
    expect(result[:total_tokens]).to eq(0)
  end

  it "returns an empty result for empty input" do
    result = pruner.prune([], max_tokens: 1000)
    expect(result[:files]).to be_empty
    expect(result[:total_tokens]).to eq(0)
  end

  it "selects no items for a zero token budget" do
    result = pruner.prune(items, max_tokens: 0)
    expect(result[:files]).to be_empty
    expect(result[:total_tokens]).to eq(0)
  end

  it "always includes zero-token items if budget is not full" do
    zero_token_item = { path: "zero.rb", estimated_tokens: 0 }
    items_with_zero = [item1, zero_token_item, item2]
    result = pruner.prune(items_with_zero, max_tokens: 150)
    expect(result[:files].map { |f| f[:path] }).to eq(["item1.rb", "zero.rb"])
    expect(result[:total_tokens]).to eq(100)
  end

  it "handles hitting the budget boundary exactly" do
    result = pruner.prune(items, max_tokens: 300)
    expect(result[:files].map { |f| f[:path] }).to eq(["item1.rb", "item2.rb"])
    expect(result[:total_tokens]).to eq(300)
  end

  it "correctly reports the total token count" do
    result = pruner.prune(items, max_tokens: 250)
    expect(result[:total_tokens]).to eq(100)
  end

  it "correctly reports the original budget value" do
    budget = 42
    result = pruner.prune(items, max_tokens: budget)
    expect(result[:budget]).to eq(budget)
  end

  context "with invalid input" do
    it "raises a TypeError for an item with a nil estimated_tokens value" do
      invalid_items = [item1, { path: "invalid.rb", estimated_tokens: nil }]
      expect { pruner.prune(invalid_items, max_tokens: 1000) }
        .to raise_error(TypeError, "nil can't be coerced into Integer")
    end

    it "raises a NoMethodError for an item with a missing estimated_tokens key" do
      invalid_items = [item1, { path: "invalid.rb" }]
      # The error is `TypeError: nil can't be coerced into Integer`
      # because `item[:estimated_tokens]` is nil, and `total + nil` is called.
      expect { pruner.prune(invalid_items, max_tokens: 1000) }
        .to raise_error(TypeError, "nil can't be coerced into Integer")
    end
  end
end
