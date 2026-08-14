require 'spec_helper'

require_relative '../../lib/context/context_engine'
require_relative '../../lib/indexing/project_index'
require_relative '../../lib/context/context_ranker'

RSpec.describe ContextEngine do
  subject(:engine) { described_class.new(project_index) }

  let(:project_index) { instance_double(ProjectIndex) }
  let(:context_ranker) { instance_double(ContextRanker) }
  let(:rule) { double('ContextRule') }
  let(:entity) { 'User' }

  let(:model_context) do
    {
      model: 'user.rb',
      primary_controller: 'users_controller.rb',
      primary_policy: 'user_policy.rb',
      related_models: ['post.rb', 'account.rb'],
      primary_views: ['users/index.html.erb']
    }
  end

  let(:model_data) do
    {
      context: model_context,
      # other keys from ProjectIndex not used by ContextEngine
    }
  end

  before do
    # Stub the main dependency, project_index
    allow(project_index).to receive(:model).with(entity).and_return(model_data)
    allow(project_index).to receive(:model).with('NonExistent').and_return(nil)

    # Stub the class dependency, ContextRanker
    allow(ContextRanker).to receive(:new).and_return(context_ranker)
    allow(context_ranker).to receive(:rank).and_return([{ file: 'user.rb', score: 100 }])

    # Default all rule methods to false
    allow(rule).to receive(:include_primary?).and_return(false)
    allow(rule).to receive(:include_controller?).and_return(false)
    allow(rule).to receive(:include_policy?).and_return(false)
    allow(rule).to receive(:include_related_models?).and_return(false)
    allow(rule).to receive(:include_views?).and_return(false)
  end

  describe '#build' do
    context 'when the entity does not exist' do
      it 'returns nil' do
        expect(engine.build('NonExistent', rule: rule)).to be_nil
      end
    end

    context 'when the entity exists' do
      it 'always includes the target and ranked results' do
        result = engine.build(entity, rule: rule)
        expect(result).to include(
          target: 'User',
          ranked: [{ file: 'user.rb', score: 100 }]
        )
      end

      it 'passes the built context to the ranker before merging ranked results' do
        allow(rule).to receive(:include_primary?).and_return(true)
        # Verify that rank is called with the context *before* the :ranked key is added
        expect(context_ranker).to receive(:rank).with({
          target: 'User',
          primary: ['user.rb']
        })
        engine.build(entity, rule: rule)
      end

      it 'passes a complex built context to the ranker' do
        allow(rule).to receive(:include_primary?).and_return(true)
        allow(rule).to receive(:include_controller?).and_return(true)
        allow(rule).to receive(:include_related_models?).and_return(true)

        expected_payload_for_ranker = {
          target: 'User',
          primary: ['user.rb'],
          required: ['users_controller.rb'],
          related: ['post.rb', 'account.rb']
        }

        expect(context_ranker).to receive(:rank).with(expected_payload_for_ranker)
        engine.build(entity, rule: rule)
      end

      it 'passes a complete context to ContextRanker before adding :ranked key' do
        allow(rule).to receive(:include_primary?).and_return(true)
        allow(rule).to receive(:include_controller?).and_return(true)
        allow(rule).to receive(:include_policy?).and_return(true)
        allow(rule).to receive(:include_related_models?).and_return(true)
        allow(rule).to receive(:include_views?).and_return(true)

        expected_context_for_ranker = {
          target: 'User',
          primary: ['user.rb'],
          required: ['users_controller.rb', 'user_policy.rb'],
          related: ['post.rb', 'account.rb'],
          optional: ['users/index.html.erb']
        }
        expect(context_ranker).to receive(:rank).with(expected_context_for_ranker)

        engine.build(entity, rule: rule)
      end

      context 'when individual rules are disabled' do
        before do
          # Enable all rules by default for these tests, then disable one by one
          allow(rule).to receive(:include_primary?).and_return(true)
          allow(rule).to receive(:include_controller?).and_return(true)
          allow(rule).to receive(:include_policy?).and_return(true)
          allow(rule).to receive(:include_related_models?).and_return(true)
          allow(rule).to receive(:include_views?).and_return(true)
        end

        it 'does not include :primary if include_primary? is false' do
          allow(rule).to receive(:include_primary?).and_return(false)
          result = engine.build(entity, rule: rule)
          expect(result).not_to have_key(:primary)
        end

        it 'does not add controller to :required if include_controller? is false' do
          allow(rule).to receive(:include_controller?).and_return(false)
          result = engine.build(entity, rule: rule)
          expect(result[:required]).to contain_exactly('user_policy.rb')
        end

        it 'does not add policy to :required if include_policy? is false' do
          allow(rule).to receive(:include_policy?).and_return(false)
          result = engine.build(entity, rule: rule)
          expect(result[:required]).to contain_exactly('users_controller.rb')
        end

        it 'does not create :required key if controller and policy are false' do
          allow(rule).to receive(:include_controller?).and_return(false)
          allow(rule).to receive(:include_policy?).and_return(false)
          result = engine.build(entity, rule: rule)
          expect(result).not_to have_key(:required)
        end

        it 'does not include :related if include_related_models? is false' do
          allow(rule).to receive(:include_related_models?).and_return(false)
          result = engine.build(entity, rule: rule)
          expect(result).not_to have_key(:related)
        end

        it 'does not include :optional if include_views? is false' do
          allow(rule).to receive(:include_views?).and_return(false)
          result = engine.build(entity, rule: rule)
          expect(result).not_to have_key(:optional)
        end
      end

      context 'with a mix of enabled and disabled rules' do
        before do
          allow(rule).to receive(:include_primary?).and_return(true)
          allow(rule).to receive(:include_related_models?).and_return(true)
          # controller, policy, and views are disabled by default
        end

        it 'only includes keys for enabled rules' do
          result = engine.build(entity, rule: rule)
          expect(result.keys).to contain_exactly(
            :target,
            :primary,
            :related,
            :ranked
          )
        end
      end

      context 'with no rules enabled' do
        it 'does not add optional keys to the result' do
          result = engine.build(entity, rule: rule)
          expect(result.keys).to contain_exactly(:target, :ranked)
        end
      end

      context 'when rule includes primary' do
        it 'adds the primary model to the result' do
          allow(rule).to receive(:include_primary?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:primary]).to contain_exactly('user.rb')
        end
      end

      context 'when rule includes controller' do
        it 'adds the primary controller to the required files' do
          allow(rule).to receive(:include_controller?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:required]).to contain_exactly('users_controller.rb')
        end
      end

      context 'when rule includes policy' do
        it 'adds the primary policy to the required files' do
          allow(rule).to receive(:include_policy?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:required]).to contain_exactly('user_policy.rb')
        end
      end

      context 'when rule includes both controller and policy' do
        it 'adds both to the required files' do
          allow(rule).to receive(:include_controller?).and_return(true)
          allow(rule).to receive(:include_policy?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:required]).to contain_exactly('users_controller.rb', 'user_policy.rb')
        end
      end

      context 'when rule includes related models' do
        it 'adds the related models to the result' do
          allow(rule).to receive(:include_related_models?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:related]).to contain_exactly('post.rb', 'account.rb')
        end

        context 'with an empty array' do
          let(:model_context) { super().merge(related_models: []) }
          it 'adds an empty array to the result' do
            allow(rule).to receive(:include_related_models?).and_return(true)
            result = engine.build(entity, rule: rule)
            expect(result[:related]).to be_empty
          end
        end
      end

      context 'when rule includes views' do
        it 'adds the primary views to the optional files' do
          allow(rule).to receive(:include_views?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:optional]).to contain_exactly('users/index.html.erb')
        end

        context 'with an empty array' do
          let(:model_context) { super().merge(primary_views: []) }
          it 'adds an empty array to the result' do
            allow(rule).to receive(:include_views?).and_return(true)
            result = engine.build(entity, rule: rule)
            expect(result[:optional]).to be_empty
          end
        end
      end

      context 'when the model context has nil values' do
        let(:model_context) do
          {
            model: 'user.rb',
            primary_controller: nil, # Missing controller
            primary_policy: 'user_policy.rb',
            related_models: [],
            primary_views: nil
          }
        end

        it 'includes nil in the required array if the context part is missing' do
          allow(rule).to receive(:include_controller?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:required]).to contain_exactly(nil)
        end
      end
      
      context 'when all rules are enabled' do
        it 'builds a complete context' do
          allow(rule).to receive(:include_primary?).and_return(true)
          allow(rule).to receive(:include_controller?).and_return(true)
          allow(rule).to receive(:include_policy?).and_return(true)
          allow(rule).to receive(:include_related_models?).and_return(true)
          allow(rule).to receive(:include_views?).and_return(true)

          result = engine.build(entity, rule: rule)

          expect(result).to include(
            target: 'User',
            primary: ['user.rb'],
            required: ['users_controller.rb', 'user_policy.rb'],
            related: ['post.rb', 'account.rb'],
            optional: ['users/index.html.erb'],
            ranked: [{ file: 'user.rb', score: 100 }]
          )
        end
      end
    end
  end
end
