require 'spec_helper'
require_relative '../lib/dependency_walker'

RSpec.describe DependencyWalker do
  subject(:walker) { described_class.new }

  def create_node(model_name, belongs_to: [], has_many: [], has_one: [], other_associations: {})
    {
      model: model_name,
      associations: {
        belongs_to: belongs_to,
        has_many: has_many,
        has_one: has_one
      }.merge(other_associations)
    }
  end

  describe '#walk_models' do
    context '1. Simple dependency' do
      let(:company_node) { { model: "Company", associations: {} } }
      let(:user_node) { create_node("User", belongs_to: [company_node]) }

      it 'returns the direct dependency' do
        expect(walker.walk_models(user_node)).to eq(["Company"])
      end
    end

    context '2. Multiple association types' do
      let(:company_node) { { model: "Company", associations: {} } }
      let(:post_node) { { model: "Post", associations: {} } }
      let(:profile_node) { { model: "Profile", associations: {} } }
      let(:user_node) do
        create_node("User",
          belongs_to: [company_node],
          has_many: [post_node],
          has_one: [profile_node]
        )
      end

      it 'returns dependencies from all specified association types' do
        expect(walker.walk_models(user_node)).to match_array(["Company", "Post", "Profile"])
      end
    end

    context '3. Nested/transitive dependencies' do
      let(:comment_node) { { model: "Comment", associations: {} } }
      let(:post_node) { create_node("Post", has_many: [comment_node]) }
      let(:user_node) { create_node("User", has_many: [post_node]) }

      it 'returns all nested dependencies in depth-first order' do
        expect(walker.walk_models(user_node)).to eq(["Post", "Comment"])
      end
    end

    context '4. Branching dependencies' do
      let(:comment_node) { { model: "Comment", associations: {} } }
      let(:post_node) { create_node("Post", has_many: [comment_node]) }
      let(:profile_node) { { model: "Profile", associations: {} } }
      let(:user_node) { create_node("User", has_many: [post_node], has_one: [profile_node]) }

      it 'returns dependencies from all branches' do
        expect(walker.walk_models(user_node)).to match_array(["Post", "Comment", "Profile"])
      end
    end

    context '5. Circular dependency' do
      let(:user_node) { create_node("User") }
      let(:post_node) { create_node("Post", belongs_to: [user_node]) }

      before do
        user_node[:associations][:has_many] = [post_node]
      end

      it 'terminates and avoids infinite recursion, returning dependencies up to the cycle' do
        expect(walker.walk_models(user_node)).to eq(["Post"])
      end
    end

    context '6. Self-reference' do
      let(:category_node) { create_node("Category") }

      before do
        category_node[:associations][:belongs_to] = [category_node]
      end

      it 'terminates and avoids infinite recursion for self-referencing models' do
        expect(walker.walk_models(category_node)).to eq([])
      end
    end

    context '7. Duplicate dependency' do
      let(:author_node) { { model: "Author", associations: {} } }
      let(:post_node) { create_node("Post", belongs_to: [author_node]) }
      let(:comment_node) { create_node("Comment", belongs_to: [author_node]) }
      let(:user_node) { create_node("User", has_many: [post_node, comment_node]) }

      it 'returns duplicate dependencies only once in the flattened result' do
        expect(walker.walk_models(user_node)).to match_array(["Post", "Author", "Comment"])
      end
    end

    context '8. Missing association categories' do
      let(:post_node) { { model: "Post", associations: {} } }
      let(:user_node) { create_node("User", has_many: [post_node], belongs_to: [], has_one: []) }

      it 'correctly processes nodes with only a subset of association types' do
        expect(walker.walk_models(user_node)).to eq(["Post"])
      end

      let(:company_node) { { model: "Company", associations: {} } }
      let(:another_user_node) { create_node("User", belongs_to: [company_node], has_many: [], has_one: []) }

      it 'correctly processes nodes with only a subset of association types (belongs_to)' do
        expect(walker.walk_models(another_user_node)).to eq(["Company"])
      end
    end

    context '9. Empty associations' do
      let(:user_node) { create_node("User") } # All associations default to empty arrays

      it 'produces an empty result for a node with empty association arrays' do
        expect(walker.walk_models(user_node)).to eq([])
      end
    end

    context '10. Missing associations key' do
      let(:user_node) { { model: "User" } } # No :associations key

      it 'does not raise an error and returns an empty result' do
        expect(walker.walk_models(user_node)).to eq([])
      end
    end

    context '11. Missing root model' do
      let(:node_without_model) { { associations: {} } }

      it 'returns an empty array when the root node has no model key' do
        expect(walker.walk_models(node_without_model)).to eq([])
      end
    end

    context '12. Nil root node' do
      it 'does not raise an error and returns an empty array when the root node is nil' do
        expect(walker.walk_models(nil)).to eq([])
      end
    end

    context '13. Unknown association type' do
      let(:unknown_node) { { model: "Unknown", associations: {} } }
      let(:user_node) { create_node("User", other_associations: { unknown_type: [unknown_node] }) }

      it 'ignores unknown association types and does not include their dependencies' do
        expect(walker.walk_models(user_node)).to eq([])
      end
    end

    context '14. Ordering' do
      let(:division_node) { { model: "Division", associations: {} } }
      let(:company_node) { create_node("Company", has_one: [division_node]) }

      let(:tag_node) { { model: "Tag", associations: {} } }
      let(:post_node) { create_node("Post", has_many: [tag_node]) }

      let(:detail_node) { { model: "Detail", associations: {} } }
      let(:profile_node) { create_node("Profile", has_one: [detail_node]) }

      let(:user_node) do
        create_node("User",
          belongs_to: [company_node],
          has_many: [post_node],
          has_one: [profile_node]
        )
      end

      it 'follows the association order (belongs_to, has_many, has_one) and recursively walks each branch' do
        expect(walker.walk_models(user_node)).to eq(["Company", "Division", "Post", "Tag", "Profile", "Detail"])
      end
    end
  end
end
