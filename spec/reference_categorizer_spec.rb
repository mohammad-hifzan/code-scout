require 'spec_helper'
require_relative '../lib/reference_categorizer'

RSpec.describe ReferenceCategorizer do
  let(:categorizer) { described_class.new }

  describe '#categorize' do
    let(:empty_result) do
      {
        models: [], controllers: [], views: [], helpers: [], policies: [],
        services: [], jobs: [], mailers: [], concerns: [], others: []
      }
    end

    it 'handles nil input gracefully' do
      expect(categorizer.categorize(nil)).to eq(empty_result)
    end

    it 'handles empty input' do
      expect(categorizer.categorize([])).to eq(empty_result)
    end

    it 'categorizes various file types correctly' do
      files = [
        '/app/models/user.rb',
        '/app/controllers/users_controller.rb',
        '/app/views/users/index.html.erb',
        '/app/policies/user_policy.rb',
        '/app/services/user_service.rb',
        '/app/jobs/user_job.rb',
        '/app/mailers/user_mailer.rb',
        '/app/helpers/user_helper.rb',
        '/db/schema.rb' # other
      ]

      result = categorizer.categorize(files)

      expect(result[:models]).to contain_exactly('/app/models/user.rb')
      expect(result[:controllers]).to contain_exactly('/app/controllers/users_controller.rb')
      expect(result[:views]).to contain_exactly('/app/views/users/index.html.erb')
      expect(result[:policies]).to contain_exactly('/app/policies/user_policy.rb')
      expect(result[:services]).to contain_exactly('/app/services/user_service.rb')
      expect(result[:jobs]).to contain_exactly('/app/jobs/user_job.rb')
      expect(result[:mailers]).to contain_exactly('/app/mailers/user_mailer.rb')
      expect(result[:helpers]).to contain_exactly('/app/helpers/user_helper.rb')
      expect(result[:others]).to contain_exactly('/db/schema.rb')
    end

    it 'categorizes model concerns correctly, not as models' do
      files = ['/app/models/concerns/commentable.rb']
      result = categorizer.categorize(files)

      expect(result[:concerns]).to contain_exactly('/app/models/concerns/commentable.rb')
      expect(result[:models]).to be_empty
    end

    it 'categorizes controller concerns correctly, not as controllers' do
      files = ['/app/controllers/concerns/authenticatable.rb']
      result = categorizer.categorize(files)

      expect(result[:concerns]).to contain_exactly('/app/controllers/concerns/authenticatable.rb')
      expect(result[:controllers]).to be_empty
    end

    it 'categorizes namespaced models correctly' do
      files = ['/app/models/admin/user.rb']
      result = categorizer.categorize(files)

      expect(result[:models]).to contain_exactly('/app/models/admin/user.rb')
      expect(result[:concerns]).to be_empty
    end
  end
end
