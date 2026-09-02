require "spec_helper"

require_relative "../../lib/nlp/request_analyzer"

RSpec.describe RequestAnalyzer do
  let(:known_models) { ["Shop", "User", "Post", "Billing::Invoice"] }
  let(:analyzer) { described_class.new(models: known_models) }

  describe "#analyze" do
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

    it "defaults to the :edit action for generic requests" do
      analysis = analyzer.analyze("some generic request")
      expect(analysis[:action]).to eq(:edit)
      expect(analysis[:entity]).to be_nil
    end

    it "resolves entity when action is lowercase" do
      expect(
        analyzer.analyze("add a validation to User")
      ).to eq(
        action: :edit,
        entity: "User"
      )
    end

    it "resolves entity when action has trailing punctuation" do
      expect(
        analyzer.analyze("Add a validation to User.")
      ).to eq(
        action: :edit,
        entity: "User"
      )
    end

    it "does not allow 'how' to override an explicit edit request" do
      expect(
        analyzer.analyze("Change how User's posts are serialized.")
      ).to eq(
        action: :edit,
        entity: "User"
      )
    end

    it "detects debug requests with error details and plural model" do
      expect(
        analyzer.analyze("Users are getting a NoMethodError when loading their posts. Fix it.")
      ).to eq(
        action: :debug,
        entity: "User"
      )
    end

    it "detects edit requests with complex descriptions" do
      expect(
        analyzer.analyze("Change the User model's status representation.")
      ).to eq(
        action: :edit,
        entity: "User"
      )
    end

    it "resolves plural model references to canonical model name" do
      expect(
        analyzer.analyze("Delete old Posts from the database")
      ).to eq(
        action: :edit,
        entity: "Post"
      )
    end

    it "resolves lowercase model references" do
      expect(
        analyzer.analyze("explain user permissions")
      ).to eq(
        action: :explain,
        entity: "User"
      )
    end

    it "resolves namespaced models" do
      expect(
        analyzer.analyze("Add total amount calculation to Billing::Invoice")
      ).to eq(
        action: :edit,
        entity: "Billing::Invoice"
      )
    end

    it "resolves demodulized reference for namespaced model" do
      expect(
        analyzer.analyze("Update Invoice tax rates")
      ).to eq(
        action: :edit,
        entity: "Billing::Invoice"
      )
    end

    it "returns nil entity when the request references an unknown model" do
      expect(
        analyzer.analyze("Add validation to Account")
      ).to eq(
        action: :edit,
        entity: nil
      )
    end

    it "never selects action keywords as entities merely because they are capitalized" do
      expect(
        analyzer.analyze("Add validation to unknown model")
      ).to eq(
        action: :edit,
        entity: nil
      )

      expect(
        analyzer.analyze("Explain unknown concept")
      ).to eq(
        action: :explain,
        entity: nil
      )

      expect(
        analyzer.analyze("Debug unexpected behavior")
      ).to eq(
        action: :debug,
        entity: nil
      )
    end

    it "does not resolve plural forms if the model does not exist in the project" do
      expect(
        analyzer.analyze("Change Orders status")
      ).to eq(
        action: :edit,
        entity: nil
      )
    end

    it "allows overriding models per analyze call" do
      scoped_analyzer = described_class.new(models: ["User"])
      expect(
        scoped_analyzer.analyze("Explain Shop", models: ["Shop"])
      ).to eq(
        action: :explain,
        entity: "Shop"
      )
    end
  end
end