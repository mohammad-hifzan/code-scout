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
      end

      context 'when rule includes views' do
        it 'adds the primary views to the optional files' do
          allow(rule).to receive(:include_views?).and_return(true)
          result = engine.build(entity, rule: rule)
          expect(result[:optional]).to contain_exactly('users/index.html.erb')
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
