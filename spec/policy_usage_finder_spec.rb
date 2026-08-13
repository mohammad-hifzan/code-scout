require 'spec_helper'
require_relative '../lib/policy_usage_finder'

RSpec.describe PolicyUsageFinder do
  describe '#used_policies' do
    it 'returns an empty array when there are no models' do
      project_map = { models: {} }
      finder = PolicyUsageFinder.new(project_map)
      expect(finder.used_policies).to eq([])
    end

    it 'returns a policy name for a single model' do
      project_map = { models: { 'User' => '/path/to/user.rb' } }
      finder = PolicyUsageFinder.new(project_map)
      expect(finder.used_policies).to eq(['UserPolicy'])
    end

    it 'returns policy names for multiple models' do
      project_map = { models: { 'User' => '/path/to/user.rb', 'Post' => '/path/to/post.rb' } }
      finder = PolicyUsageFinder.new(project_map)
      expect(finder.used_policies).to contain_exactly('UserPolicy', 'PostPolicy')
    end

    it 'handles namespaced models' do
      project_map = { models: { 'Admin::User' => '/path/to/admin/user.rb' } }
      finder = PolicyUsageFinder.new(project_map)
      expect(finder.used_policies).to eq(['Admin::UserPolicy'])
    end

    it 'handles model keys as symbols' do
      project_map = { models: { User: '/path/to/user.rb' } }
      finder = PolicyUsageFinder.new(project_map)
      expect(finder.used_policies).to eq(['UserPolicy'])
    end

    context 'with malformed input' do
      it 'returns an empty array if the models key is missing' do
        project_map = { controllers: {} }
        finder = PolicyUsageFinder.new(project_map)
        expect(finder.used_policies).to eq([])
      end

      it 'returns an empty array if project_map is nil' do
        finder = PolicyUsageFinder.new(nil)
        expect(finder.used_policies).to eq([])
      end
    end
  end
end
