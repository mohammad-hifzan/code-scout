require 'spec_helper'
require_relative '../lib/dependency_walker'

RSpec.describe DependencyWalker do
  subject(:walker) { described_class.new }

  # Helper to build the nested hash structure for nodes
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
    # Test case 1: Basic functionality with a direct dependency
    context 'when a node has a direct dependency' do
      let(:company_node) { create_node("Company") }
      let(:user_node) { create_node("User", belongs_to: [company_node]) }

      it 'returns the direct dependency' do
        expect(walker.walk_models(user_node)).to match_array(["Company"])
      end
    end

    # Test case 2: Multiple dependencies from different association types
    context 'when a node has multiple dependencies across different association types' do
      let(:company_node) { create_node("Company") }
      let(:post_node) { create_node("Post") }
      let(:profile_node) { create_node("Profile") }
      let(:user_node) do
        create_node("User",
          belongs_to: [company_node],
          has_many: [post_node],
          has_one: [profile_node]
        )
      end

      it 'returns all unique dependencies' do
        expect(walker.walk_models(user_node)).to match_array(["Company", "Post", "Profile"])
      end
    end

    # Test case 3: Transitive (nested) dependencies
    context 'when a node has transitive dependencies' do
      let(:comment_node) { create_node("Comment") }
      let(:post_node) { create_node("Post", has_many: [comment_node]) }
      let(:user_node) { create_node("User", has_many: [post_node]) }

      it 'returns all nested dependencies' do
        expect(walker.walk_models(user_node)).to match_array(["Post", "Comment"])
      end
    end

    # Test case 4: Branching dependencies
    context 'when a node has multiple branches of dependencies' do
      let(:comment_node) { create_node("Comment") }
      let(:post_node) { create_node("Post", has_many: [comment_node]) }
      let(:profile_node) { create_node("Profile") }
      let(:user_node) { create_node("User", has_many: [post_node], has_one: [profile_node]) }

      it 'returns dependencies from all branches' do
        expect(walker.walk_models(user_node)).to match_array(["Post", "Comment", "Profile"])
      end
    end

    # Test case 5: Cycle detection
    context 'when there is a circular dependency' do
      # User -> Post -> User
      let(:user_node) { create_node("User") }
      let(:post_node) { create_node("Post", belongs_to: [user_node]) }

      before do
        # Complete the cycle
        user_node[:associations][:has_many] = [post_node]
      end

      it 'terminates and does not go into an infinite loop' do
        expect { walker.walk_models(user_node) }.not_to raise_error
      end

      it 'returns the dependency up to the point of the cycle' do
        expect(walker.walk_models(user_node)).to match_array(["Post"])
      end
    end

    # Test case 6: Self-referencing node
    context 'when a node refers to itself' do
      let(:category_node) { create_node("Category") }

      before do
        category_node[:associations][:belongs_to] = [category_node]
      end

      it 'terminates and returns an empty array' do
        expect(walker.walk_models(category_node)).to be_empty
      end
    end

    # Test case 7: Duplicate dependencies are returned only once
    context 'when the same dependency is reached through different paths' do
      # User -> Post -> Author
      # User -> Comment -> Author
      let(:author_node) { create_node("Author") }
      let(:post_node) { create_node("Post", belongs_to: [author_node]) }
      let(:comment_node) { create_node("Comment", belongs_to: [author_node]) }
      let(:user_node) { create_node("User", has_many: [post_node, comment_node]) }

      it 'includes the duplicate dependency only once in the result' do
        expect(walker.walk_models(user_node)).to match_array(["Post", "Comment", "Author"])
      end
    end

    # Test case for preserving traversal across sibling branches (user request 8)
    context 'when a shared dependency is present in different branches' do
      # User -> Post -> Author
      # User -> Notification -> Author
      let(:author_node) { create_node("Author") }
      let(:post_node) { create_node("Post", has_many: [author_node]) }
      let(:notification_node) { create_node("Notification", has_many: [author_node]) }
      let(:user_node) { create_node("User", has_many: [post_node, notification_node]) }

      it 'traverses all branches correctly and returns unique dependencies' do
        expect(walker.walk_models(user_node)).to match_array(["Post", "Notification", "Author"])
      end
    end

    # NEW: Test case for excluding the root model (user request 6)
    context 'when the root model appears as a dependency of another node' do
      # User -> Post -> User (cycle)
      # Post -> Comment
      let(:user_node) { create_node("User") }
      let(:comment_node) { create_node("Comment") }
      let(:post_node) { create_node("Post", belongs_to: [user_node], has_many: [comment_node]) }
      
      before do
        user_node[:associations][:has_many] = [post_node]
      end
      
      it 'excludes the root model from the dependency list' do
        expect(walker.walk_models(user_node)).not_to include("User")
      end

      it 'still includes other valid dependencies' do
        expect(walker.walk_models(user_node)).to match_array(["Post", "Comment"])
      end
    end

    # Edge case: Node with a subset of association types
    context 'when a node has only a subset of association types' do
      let(:post_node) { create_node("Post") }
      let(:user_node) { create_node("User", has_many: [post_node], belongs_to: [], has_one: []) }

      it 'correctly processes the node' do
        expect(walker.walk_models(user_node)).to match_array(["Post"])
      end
    end

    # Edge case: Node with empty associations
    context 'when a node has empty associations' do
      let(:user_node) { create_node("User") }

      it 'returns an empty array' do
        expect(walker.walk_models(user_node)).to be_empty
      end
    end

    # Edge case: Node missing the :associations key
    context 'when a node is missing the :associations key' do
      let(:user_node) { { model: "User" } }

      it 'returns an empty array without raising an error' do
        expect(walker.walk_models(user_node)).to be_empty
      end
    end

    # Edge case: Root node without a :model key (user request 2)
    context 'when the root node is missing the :model key' do
      let(:node_without_model) { { associations: {} } }

      it 'returns an empty array' do
        expect(walker.walk_models(node_without_model)).to be_empty
      end
    end

    # Edge case: nil child in associations
    context 'when an association array contains a nil child' do
        let(:user_node) { create_node("User", has_many: [nil]) }

        it 'handles it gracefully without errors' do
            expect(walker.walk_models(user_node)).to be_empty
        end
    end

    # Edge case: Child node without a model
    context 'when a child node is missing the :model key' do
        let(:child_without_model) { { associations: {} } }
        let(:user_node) { create_node("User", has_many: [child_without_model]) }

        it 'handles it gracefully and does not add nil to dependencies' do
            expect(walker.walk_models(user_node)).to be_empty
        end
    end

    # Edge case: Nil root node (user request 1)
    context 'when the root node is nil' do
      it 'returns an empty array without raising an error' do
        expect(walker.walk_models(nil)).to be_empty
      end
    end

    # Edge case: Unknown association types are ignored
    context 'when a node has unknown association types' do
      let(:unknown_node) { create_node("Unknown") }
      let(:user_node) { create_node("User", other_associations: { unknown_type: [unknown_node] }) }

      it 'ignores them and returns an empty array' do
        expect(walker.walk_models(user_node)).to be_empty
      end
    end
  end
end
