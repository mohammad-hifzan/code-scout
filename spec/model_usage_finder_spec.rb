require 'spec_helper'
require_relative '../lib/model_usage_finder'

RSpec.describe ModelUsageFinder do
  let(:project_map) do
    {
      models: {}
    }
  end
  let(:finder) { ModelUsageFinder.new(project_map) }

  describe '#used_models' do
    context 'when there are no models' do
      it 'returns an empty array' do
        expect(finder.used_models).to be_empty
      end
    end

    context 'with a simple has_many association' do
      let(:project_map) do
        {
          models: {
            'User' => { associations: { has_many: [], belongs_to: [], has_one: [] } },
            'Post' => { associations: { has_many: [:users], belongs_to: [], has_one: [] } }
          }
        }
      end

      it 'identifies the associated model' do
        expect(finder.used_models).to contain_exactly('User')
      end
    end

    context 'with various association types' do
      let(:project_map) do
        {
          models: {
            'User' => { associations: { has_many: [], belongs_to: [:profile], has_one: [] } },
            'Post' => { associations: { has_many: [:comments], belongs_to: [], has_one: [] } },
            'Comment' => { associations: { has_many: [], belongs_to: [], has_one: [] } },
            'Profile' => { associations: { has_many: [], belongs_to: [], has_one: [] } }
          }
        }
      end

      it 'identifies all associated models from has_many, belongs_to, and has_one' do
        expect(finder.used_models).to contain_exactly('Comment', 'Profile')
      end
    end

    context 'when an association is mentioned multiple times' do
      let(:project_map) do
        {
          models: {
            'User' => { associations: { has_many: [:posts], belongs_to: [], has_one: [] } },
            'Admin' => { associations: { has_many: [:posts], belongs_to: [], has_one: [] } },
            'Post' => { associations: { has_many: [], belongs_to: [], has_one: [] } }
          }
        }
      end

      it 'returns a unique list of models' do
        expect(finder.used_models).to contain_exactly('Post')
      end
    end

    context 'with namespaced models in associations' do
      let(:project_map) do
        {
          models: {
            'Post' => { associations: { has_many: [:'admin/users'], belongs_to: [], has_one: [] } },
            'Admin::User' => { associations: { has_many: [], belongs_to: [], has_one: [] } }
          }
        }
      end

      it 'correctly identifies the namespaced model' do
        # This is expected to fail with the current implementation
        expect(finder.used_models).to contain_exactly('Admin::User')
      end
    end

    context 'with associations using class_name' do
      # The ModelAnalyzer does not currently extract the class_name, only the association name.
      # This test documents the current behavior of ModelUsageFinder given its flawed input.
      let(:project_map) do
        {
          models: {
            'User' => { associations: { has_many: [:authored_posts], belongs_to: [], has_one: [] } },
            'Post' => { associations: { has_many: [], belongs_to: [], has_one: [] } }
          }
        }
      end

      it 'infers the model name from the association name, not the class_name' do
        expect(finder.used_models).to contain_exactly('AuthoredPost')
        expect(finder.used_models).to_not include('Post')
      end
    end

    context 'when association includes class_name (hypothetical improved analyzer)' do
      let(:project_map) do
        {
          models: {
            'User' => {
              associations: {
                has_many: [
                  :posts, # old format
                  { name: :authored_posts, class_name: 'SpecialPost' } # new format
                ],
                belongs_to: [],
                has_one: []
              }
            },
            'Post' => { associations: { has_many: [], belongs_to: [], has_one: [] } },
            'SpecialPost' => { associations: { has_many: [], belongs_to: [], has_one: [] } }
          }
        }
      end

      it 'prefers the class_name when available and handles mixed formats' do
        expect(finder.used_models).to contain_exactly('Post', 'SpecialPost')
      end
    end


  end
end
