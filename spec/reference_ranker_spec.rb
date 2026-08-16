require 'spec_helper'
require 'active_support/core_ext/string'
require_relative '../lib/reference_ranker'

RSpec.describe ReferenceRanker do
  describe '#rank' do
    let(:empty_ranks) { { primary: [], secondary: [], tertiary: [] } }

    context 'with a simple model' do
      let(:ranker) { described_class.new('User') }

      it 'ranks the model file as primary' do
        result = ranker.rank({ models: ['/app/models/user.rb'] })
        expect(result[:primary]).to include('/app/models/user.rb')
      end

      it 'ranks the controller file as primary' do
        result = ranker.rank({ controllers: ['/app/controllers/users_controller.rb'] })
        expect(result[:primary]).to include('/app/controllers/users_controller.rb')
      end

      it 'ranks the policy file as primary' do
        result = ranker.rank({ policies: ['/app/policies/user_policy.rb'] })
        expect(result[:primary]).to include('/app/policies/user_policy.rb')
      end

      it 'ranks other models and controllers as secondary' do
        files = {
          models: ['/app/models/post.rb'],
          controllers: ['/app/controllers/posts_controller.rb']
        }
        result = ranker.rank(files)
        expect(result[:secondary]).to contain_exactly('/app/models/post.rb', '/app/controllers/posts_controller.rb')
      end

      it 'ranks views as tertiary' do
        result = ranker.rank({ views: ['/app/views/users/index.html.erb'] })
        expect(result[:tertiary]).to include('/app/views/users/index.html.erb')
      end

      it 'handles duplicates by returning unique file paths' do
        files = {
          models: ['/app/models/user.rb', '/app/models/user.rb'],
          secondary: ['/app/models/post.rb', '/app/models/post.rb']
        }
        result = ranker.rank(files)
        expect(result[:primary]).to eq(['/app/models/user.rb'])
        expect(result[:secondary]).to eq(['/app/models/post.rb'])
      end
    end

    context 'with a namespaced model' do
      let(:ranker) { described_class.new('Admin::User') }

      it 'ranks the namespaced model file as primary (BUG)' do
        files = { models: ['/app/models/admin/user.rb'] }
        result = ranker.rank(files)
        expect(result[:primary]).to include('/app/models/admin/user.rb')
      end

      it 'ranks the namespaced controller file as primary (BUG)' do
        files = { controllers: ['/app/controllers/admin/users_controller.rb'] }
        result = ranker.rank(files)
        expect(result[:primary]).to include('/app/controllers/admin/users_controller.rb')
      end

      it 'ranks the namespaced policy file as primary (BUG)' do
        files = { policies: ['/app/policies/admin/user_policy.rb'] }
        result = ranker.rank(files)
        expect(result[:primary]).to include('/app/policies/admin/user_policy.rb')
      end
    end

    context 'with edge case inputs' do
      it 'handles an empty hash' do
        ranker = described_class.new('User')
        expect(ranker.rank({})).to eq(empty_ranks)
      end

      it 'handles nil input for rank' do
        ranker = described_class.new('User')
        expect(ranker.rank(nil)).to eq(empty_ranks)
      end

      it 'handles nil model_name safely' do
        ranker = described_class.new(nil)
        files = { models: ['/app/models/user.rb'] }

        # It should not crash
        expect { ranker.rank(files) }.not_to raise_error

        # It should rank the file as secondary (generic model rule) instead of primary
        result = ranker.rank(files)
        expect(result[:primary]).to be_empty
        expect(result[:secondary]).to include('/app/models/user.rb')
      end

      it 'ranks files with no matching rule as tertiary' do
        ranker = described_class.new('User')
        files = { others: ['/lib/some_other_file.rb'] }
        result = ranker.rank(files)
        expect(result[:tertiary]).to include('/lib/some_other_file.rb')
      end
    end
  end
end
