# spec/analysis/association_resolver_spec.rb
require "spec_helper"
require_relative "../../lib/analysis/association_resolver"

RSpec.describe AssociationResolver do
  let(:project_map) do
    {
      models: {
        "User" => { path: "/app/models/user.rb" },
        "Post" => { path: "/app/models/post.rb" },
        "Comment" => { path: "/app/models/comment.rb" },
        "OrderItem" => { path: "/app/models/order_item.rb" },
        "Tag" => { path: "/app/models/tag.rb" },
        "Tagging" => { path: "/app/models/tagging.rb" },
        "Profile" => { path: "/app/models/profile.rb" },
        "Customer" => { path: "/app/models/customer.rb" },
        "Billing::Invoice" => { path: "/app/models/billing/invoice.rb" },
        "Billing::Customer" => { path: "/app/models/billing/customer.rb" },
        "Billing::Payment" => { path: "/app/models/billing/payment.rb" },
        "Billing::Record" => { path: "/app/models/billing/record.rb" },
        "Admin::User" => { path: "/app/models/admin/user.rb" }
      }
    }
  end

  subject(:resolver) { described_class.new(project_map) }

  describe ".resolve convenience method" do
    it "resolves via class method without needing an explicit instance" do
      result = described_class.resolve("User", { name: "posts" }, project_map)
      expect(result).to eq({ target_model: "Post", through_model: nil })
    end
  end

  describe "#resolve" do
    context "with normal associations" do
      it "resolves has_many association to conventional singular CamelCase model" do
        result = resolver.resolve("User", { name: "posts" })
        expect(result).to eq({ target_model: "Post", through_model: nil })
      end

      it "resolves belongs_to association to conventional CamelCase model" do
        result = resolver.resolve("Post", { name: "user" })
        expect(result).to eq({ target_model: "User", through_model: nil })
      end

      it "resolves has_one association to conventional CamelCase model" do
        result = resolver.resolve("User", { name: "profile" })
        expect(result).to eq({ target_model: "Profile", through_model: nil })
      end
    end

    context "with class_name option" do
      it "prefers explicit class_name over association name" do
        result = resolver.resolve("Order", { name: "items", class_name: "OrderItem" })
        expect(result).to eq({ target_model: "OrderItem", through_model: nil })
      end

      it "preserves explicit namespaced class_name verbatim" do
        result = resolver.resolve("Order", { name: "author", class_name: "Admin::User" })
        expect(result).to eq({ target_model: "Admin::User", through_model: nil })
      end

      it "handles class_name given as symbol" do
        result = resolver.resolve("Order", { name: "items", class_name: :OrderItem })
        expect(result).to eq({ target_model: "OrderItem", through_model: nil })
      end
    end

    context "with through option without source" do
      it "resolves through model from through option and target model from association name" do
        result = resolver.resolve("Post", { name: "tags", through: "taggings" })
        expect(result).to eq({
          target_model: "Tag",
          through_model: "Tagging"
        })
      end
    end

    context "with through and source options" do
      it "resolves through model from through option and target model from source option" do
        result = resolver.resolve("Post", { name: "commenters", through: "comments", source: "user" })
        expect(result).to eq({
          target_model: "User",
          through_model: "Comment"
        })
      end
    end

    context "with namespace-aware resolution" do
      it "prefers same-namespace model when it exists in the project map" do
        result = resolver.resolve("Billing::Invoice", { name: "customer" })
        expect(result).to eq({
          target_model: "Billing::Customer",
          through_model: nil
        })
      end

      it "falls back to top-level model when same-namespace model does not exist" do
        # Model 'User' exists at top level, but 'Billing::User' does not
        result = resolver.resolve("Billing::Invoice", { name: "user" })
        expect(result).to eq({
          target_model: "User",
          through_model: nil
        })
      end

      it "resolves namespaced through and source models when they exist in namespace" do
        result = resolver.resolve(
          "Billing::Invoice",
          { name: "transactions", through: "payments", source: "record" }
        )
        expect(result).to eq({
          target_model: "Billing::Record",
          through_model: "Billing::Payment"
        })
      end

      it "does not prefix explicit class_name with the enclosing namespace" do
        result = resolver.resolve(
          "Billing::Invoice",
          { name: "administrator", class_name: "Admin::User" }
        )
        expect(result[:target_model]).to eq("Admin::User")
      end
    end

    context "with legacy scalar input" do
      it "handles symbol association names" do
        result = resolver.resolve("User", :posts)
        expect(result).to eq({ target_model: "Post", through_model: nil })
      end

      it "handles string association names" do
        result = resolver.resolve("User", "posts")
        expect(result).to eq({ target_model: "Post", through_model: nil })
      end
    end

    context "with missing / empty / malformed metadata" do
      it "returns nil target and through when assoc_data is nil" do
        result = resolver.resolve("User", nil)
        expect(result).to eq({ target_model: nil, through_model: nil })
      end

      it "returns nil target and through when assoc_data is empty hash" do
        result = resolver.resolve("User", {})
        expect(result).to eq({ target_model: nil, through_model: nil })
      end

      it "returns nil target and through when assoc_data has empty string name" do
        result = resolver.resolve("User", { name: "" })
        expect(result).to eq({ target_model: nil, through_model: nil })
      end
    end

    context "when target or through model does not exist in project map" do
      it "still returns conventional target model name when project map does not contain it" do
        result = resolver.resolve("User", { name: "unknown_models" })
        expect(result[:target_model]).to eq("UnknownModel")
      end

      it "still returns conventional through model name when project map does not contain it" do
        result = resolver.resolve("User", { name: "tags", through: "non_existent_join" })
        expect(result[:through_model]).to eq("NonExistentJoin")
      end
    end

    context "polymorphic associations (documented limitation)" do
      # ModelAnalyzer does not currently extract polymorphic: true or as: :likeable.
      # When given an association name pointing to an interface, AssociationResolver
      # inflects the symbol conventionally without pretending to know concrete models.
      it "inflects the name without fabricating concrete polymorphic targets" do
        result = resolver.resolve("Picture", { name: "imageable" })
        expect(result[:target_model]).to eq("Imageable")
      end
    end
  end

  describe "helper accessors" do
    it "provides #target_model helper" do
      expect(resolver.target_model("User", { name: "posts" })).to eq("Post")
    end

    it "provides #through_model helper" do
      expect(resolver.through_model("Post", { name: "tags", through: "taggings" })).to eq("Tagging")
    end
  end
end
