require 'spec_helper'
require_relative '../../lib/graph/graph_builder'

RSpec.describe GraphBuilder do
  subject(:builder) { described_class.new(project_map) }

  def empty_associations
    { associations: { belongs_to: [], has_many: [], has_one: [] } }
  end

  describe '#build' do
    context 'with a simple belongs_to association' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: ["company"], has_many: [], has_one: [] } },
            "Company" => empty_associations
          }
        }
      end

      it 'returns a graph with the associated model' do
        graph = builder.build("User")
        expect(graph[:model]).to eq("User")
        company_node = graph[:associations][:belongs_to].first
        expect(company_node[:model]).to eq("Company")
      end
    end

    context 'with a has_many association' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: [], has_many: ["posts"], has_one: [] } },
            "Post" => empty_associations
          }
        }
      end

      it 'resolves the plural name and includes the model' do
        graph = builder.build("User")
        post_node = graph[:associations][:has_many].first
        expect(post_node[:model]).to eq("Post")
      end
    end

    context 'with a has_one association' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: [], has_many: [], has_one: ["profile"] } },
            "Profile" => empty_associations
          }
        }
      end

      it 'returns a graph with the associated model' do
        graph = builder.build("User")
        profile_node = graph[:associations][:has_one].first
        expect(profile_node[:model]).to eq("Profile")
      end
    end

    context 'with multiple association types' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: ["company"], has_many: ["posts"], has_one: ["profile"] } },
            "Company" => empty_associations,
            "Post" => empty_associations,
            "Profile" => empty_associations
          }
        }
      end

      it 'populates each association category correctly' do
        graph = builder.build("User")
        expect(graph[:associations][:belongs_to].first[:model]).to eq("Company")
        expect(graph[:associations][:has_many].first[:model]).to eq("Post")
        expect(graph[:associations][:has_one].first[:model]).to eq("Profile")
      end
    end

    context 'with nested dependencies' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: [], has_many: ["posts"], has_one: [] } },
            "Post" => { associations: { belongs_to: [], has_many: ["comments"], has_one: [] } },
            "Comment" => empty_associations
          }
        }
      end

      it 'returns a deeply nested graph' do
        graph = builder.build("User")
        post_node = graph[:associations][:has_many].first
        expect(post_node[:model]).to eq("Post")
        comment_node = post_node[:associations][:has_many].first
        expect(comment_node[:model]).to eq("Comment")
      end
    end

    context 'with a circular dependency' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: [], has_many: ["posts"], has_one: [] } },
            "Post" => { associations: { belongs_to: ["user"], has_many: [], has_one: [] } }
          }
        }
      end

      it 'terminates and does not recurse infinitely' do
        graph = builder.build("User")
        post_node = graph[:associations][:has_many].first
        expect(post_node[:model]).to eq("Post")
        # The recursive `user` association should be empty because `User` was already visited.
        expect(post_node[:associations][:belongs_to]).to be_empty
      end
    end

    context 'with a self-referencing association' do
      let(:project_map) do
        {
          models: {
            "Category" => { associations: { belongs_to: ["parent"], has_many: [], has_one: [] } }
          }
        }
      end

      it 'terminates and does not recurse infinitely' do
        # Note: The implementation singularizes 'parent' to 'parent', which won't match 'Category'.
        # This test exposes that limitation. If it was `belongs_to: ['category']`, it would be a true self-reference.
        graph = builder.build("Category")
        # We expect this to be empty because 'parent'.camelize is 'Parent', which is not in the map.
        # If the association was `belongs_to: ['category']`, we'd expect it to be empty due to the visited check.
        expect(graph[:associations][:belongs_to]).to be_empty
      end

      it 'handles a direct self-reference' do
        project_map_self = {
          models: {
            "Category" => { associations: { belongs_to: ["category"], has_many: [], has_one: [] } }
          }
        }
        builder_self = described_class.new(project_map_self)
        graph = builder_self.build("Category")
        expect(graph[:associations][:belongs_to]).to be_empty
      end
    end

    context 'with a missing associated model in project_map' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: ["company"], has_many: [], has_one: [] } }
            # No "Company" model defined
          }
        }
      end

      it 'omits the missing model and does not raise an exception' do
        graph = builder.build("User")
        expect(graph[:associations][:belongs_to]).to be_empty
      end
    end

    context 'with a missing root model' do
      let(:project_map) { { models: {} } }

      it 'returns nil' do
        expect(builder.build("NonExistentModel")).to be_nil
      end
    end

    context 'with an empty project map' do
      let(:project_map) { {} }

      it 'returns nil safely' do
        expect(builder.build("User")).to be_nil
      end
    end

    context 'with multiple branches sharing the same dependency' do
      let(:project_map) do
        {
          models: {
            "User" => { associations: { belongs_to: [], has_many: ["posts", "notifications"], has_one: [] } },
            "Post" => { associations: { belongs_to: ["author"], has_many: [], has_one: [] } },
            "Notification" => { associations: { belongs_to: ["author"], has_many: [], has_one: [] } },
            "Author" => empty_associations
          }
        }
      end

      it 'includes the shared dependency under each branch that references it' do
        graph = builder.build("User")
        post_node = graph[:associations][:has_many].find { |n| n[:model] == "Post" }
        notification_node = graph[:associations][:has_many].find { |n| n[:model] == "Notification" }

        # The `Author` dependency is found under `Post`.
        expect(post_node[:associations][:belongs_to].first[:model]).to eq("Author")

        # The `Author` dependency is also found under `Notification`.
        expect(notification_node[:associations][:belongs_to].first[:model]).to eq("Author")
      end
    end

    context 'with association name normalization' do
      let(:project_map) do
        {
          models: {
            "Root" => { associations: { belongs_to: ["user_profile"], has_many: ["special_comments"], has_one: [] } },
            "UserProfile" => empty_associations,
            "SpecialComment" => empty_associations
          }
        }
      end

      it 'correctly singularizes and camelizes association names' do
        graph = builder.build("Root")
        expect(graph[:associations][:belongs_to].first[:model]).to eq("UserProfile")
        expect(graph[:associations][:has_many].first[:model]).to eq("SpecialComment")
      end
    end
  end
end
