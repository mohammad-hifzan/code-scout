require 'spec_helper'

require_relative '../../lib/context/context_ranker'

RSpec.describe ContextRanker do
  subject(:ranker) { described_class.new }

  describe '#rank' do
    context 'with a comprehensive context' do
      let(:context) do
        {
          primary: ['/path/to/model.rb'],
          required: ['/path/to/controller.rb', '/path/to/policy.rb'],
          related: ['/path/to/related_model_1.rb', '/path/to/related_model_2.rb'],
          optional: ['/path/to/view.html.erb']
        }
      end

      it 'assigns correct scores and categories to each item' do
        ranked_result = ranker.rank(context)
        expect(ranked_result).to include(
          { path: '/path/to/model.rb', category: :primary, score: 100 },
          { path: '/path/to/controller.rb', category: :required, score: 80 },
          { path: '/path/to/policy.rb', category: :required, score: 80 },
          { path: '/path/to/related_model_1.rb', category: :related, score: 60 },
          { path: '/path/to/related_model_2.rb', category: :related, score: 60 },
          { path: '/path/to/view.html.erb', category: :optional, score: 30 }
        )
      end

      it 'sorts the items by score in descending order' do
        ranked_result = ranker.rank(context)
        expect(ranked_result.first[:score]).to eq(100)
        expect(ranked_result[1][:score]).to eq(80)
        expect(ranked_result[2][:score]).to eq(80)
        expect(ranked_result.last[:score]).to eq(30)

        # Verify overall sorted order (paths might vary for same score)
        scores = ranked_result.map { |entry| entry[:score] }
        expect(scores).to eq(scores.sort.reverse)
      end

      it 'returns the correct number of ranked items' do
        expect(ranker.rank(context).size).to eq(6)
      end
    end

    context 'with an empty context' do
      it 'returns an empty array' do
        expect(ranker.rank({})).to be_empty
      end
    end

    context 'with context containing missing categories' do
      let(:context) do
        {
          primary: ['/path/to/model.rb'],
          optional: ['/path/to/view.html.erb']
        }
      end

      it 'ranks only the present categories' do
        ranked_result = ranker.rank(context)
        expect(ranked_result.size).to eq(2)
        expect(ranked_result).to include(
          { path: '/path/to/model.rb', category: :primary, score: 100 },
          { path: '/path/to/view.html.erb', category: :optional, score: 30 }
        )
        expect(ranked_result.first[:score]).to eq(100)
      end
    end

    context 'with context containing empty category arrays' do
      let(:context) do
        {
          primary: [],
          required: ['/path/to/controller.rb']
        }
      end

      it 'ignores empty arrays' do
        ranked_result = ranker.rank(context)
        expect(ranked_result.size).to eq(1)
        expect(ranked_result).to include(
          { path: '/path/to/controller.rb', category: :required, score: 80 }
        )
      end
    end

    context 'with context containing nil values in category arrays' do
      let(:context) do
        {
          required: ['/path/to/controller.rb', nil, '/path/to/policy.rb']
        }
      end

      it 'includes nil paths in the ranked result' do
        ranked_result = ranker.rank(context)
        expect(ranked_result.size).to eq(3)
        expect(ranked_result).to include(
          { path: '/path/to/controller.rb', category: :required, score: 80 },
          { path: nil, category: :required, score: 80 },
          { path: '/path/to/policy.rb', category: :required, score: 80 }
        )
      end
    end

    context 'with items having the same score (ties)' do
      let(:context) do
        {
          required: ['/path/to/req_1.rb', '/path/to/req_2.rb'],
          related: ['/path/to/rel_1.rb', '/path/to/rel_2.rb']
        }
      end

      it 'includes all tied items with their correct scores' do
        ranked_result = ranker.rank(context)
        expect(ranked_result.size).to eq(4)
        expect(ranked_result).to include(
          { path: '/path/to/req_1.rb', category: :required, score: 80 },
          { path: '/path/to/req_2.rb', category: :required, score: 80 },
          { path: '/path/to/rel_1.rb', category: :related, score: 60 },
          { path: '/path/to/rel_2.rb', category: :related, score: 60 }
        )
        # Verify scores are sorted, order within ties doesn't matter
        expect(ranked_result.map { |entry| entry[:score] }).to eq([80, 80, 60, 60])
      end
    end
  end
end
