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

      it 'omits nil paths from the ranked result' do
        ranked_result = ranker.rank(context)
        expect(ranked_result.size).to eq(2)
        expect(ranked_result).to contain_exactly(
          { path: '/path/to/controller.rb', category: :required, score: 80 },
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

    context 'with category values as single strings instead of arrays' do
      let(:context) do
        {
          primary: '/path/to/single_model.rb',
          optional: '/path/to/single_view.html.erb'
        }
      end

      it 'correctly ranks single string paths as if they were in an array' do
        ranked_result = ranker.rank(context)

        expect(ranked_result.size).to eq(2)
        expect(ranked_result).to include(
          { path: '/path/to/single_model.rb', category: :primary, score: 100 },
          { path: '/path/to/single_view.html.erb', category: :optional, score: 30 }
        )
        expect(ranked_result.first[:path]).to eq('/path/to/single_model.rb')
      end
    end

    context 'with context containing unknown categories' do
      let(:context) do
        {
          primary: ['/path/to/model.rb'],
          unknown_category: ['/path/to/unknown.rb']
        }
      end

      it 'ignores unknown categories and only ranks known ones' do
        ranked_result = ranker.rank(context)

        expect(ranked_result).to contain_exactly(
          { path: '/path/to/model.rb', category: :primary, score: 100 }
        )
      end
    end

    context 'with duplicate paths across categories' do
      it 'favors primary over related for the same file path' do
        context = {
          primary: ['/project/app/models/user.rb'],
          related: ['/project/app/models/user.rb']
        }

        expect(ranker.rank(context)).to eq([
          { path: '/project/app/models/user.rb', category: :primary, score: 100 }
        ])
      end

      it 'favors required over related for the same file path' do
        context = {
          required: ['/project/app/models/user.rb'],
          related: ['/project/app/models/user.rb']
        }

        expect(ranker.rank(context)).to eq([
          { path: '/project/app/models/user.rb', category: :required, score: 80 }
        ])
      end

      it 'favors primary when the same path appears in all four categories' do
        context = {
          primary: ['/project/app/models/user.rb'],
          required: ['/project/app/models/user.rb'],
          related: ['/project/app/models/user.rb'],
          optional: ['/project/app/models/user.rb']
        }

        result = ranker.rank(context)
        expect(result.size).to eq(1)
        expect(result).to eq([
          { path: '/project/app/models/user.rb', category: :primary, score: 100 }
        ])
      end

      it 'preserves all distinct files while deduplicating shared ones' do
        context = {
          primary: ['/project/app/models/user.rb'],
          required: ['/project/app/controllers/users_controller.rb'],
          related: ['/project/app/models/user.rb', '/project/app/models/post.rb'],
          optional: ['/project/app/views/users/index.html.erb', '/project/app/models/post.rb']
        }

        result = ranker.rank(context)
        expect(result).to eq([
          { path: '/project/app/models/user.rb', category: :primary, score: 100 },
          { path: '/project/app/controllers/users_controller.rb', category: :required, score: 80 },
          { path: '/project/app/models/post.rb', category: :related, score: 60 },
          { path: '/project/app/views/users/index.html.erb', category: :optional, score: 30 }
        ])
      end
    end
  end
end
