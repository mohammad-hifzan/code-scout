require "spec_helper"
require_relative "../../lib/context/context_ranker"

RSpec.describe ContextRanker do
  subject(:ranker) { described_class.new }

  let(:context) do
    {
      primary: ["model.rb"],
      required: ["controller.rb", "policy.rb"],
      related: ["user.rb"],
      optional: ["view.html.erb"]
    }
  end

  it "assigns scores in descending priority" do
    ranked = ranker.rank(context)

    expect(ranked).to eq(
      [
        { path: "model.rb", category: :primary, score: 100 },
        { path: "controller.rb", category: :required, score: 80 },
        { path: "policy.rb", category: :required, score: 80 },
        { path: "user.rb", category: :related, score: 60 },
        { path: "view.html.erb", category: :optional, score: 30 }
      ]
    )
  end
end