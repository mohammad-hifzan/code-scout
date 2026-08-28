require 'spec_helper'
require 'fileutils'
require 'tmpdir'

require_relative '../../lib/context/context_builder'
require_relative '../../lib/analysis/dependency_analyzer'
require_relative '../../lib/indexing/project_mapper'
require_relative '../../lib/analysis/model_analyzer'

RSpec.describe 'DependencyAnalyzer Integration' do
  subject(:analyzer) { DependencyAnalyzer.new(project_map, project_path) }

  let!(:project_path) { Dir.mktmpdir }
  let(:project_map) { ProjectMapper.new(project_path).map }

  after { FileUtils.remove_entry(project_path) }

  def create_model_file(name, content)
    full_path = File.join(project_path, 'app', 'models', "#{name}.rb")
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  context "with 'class_name' option in has_many" do
    before do
      create_model_file(
        'order',
        <<~RUBY
          class Order < ApplicationRecord
            has_many :items, class_name: "OrderItem"
          end
        RUBY
      )
      create_model_file(
        'order_item',
        <<~RUBY
          class OrderItem < ApplicationRecord
            belongs_to :order
          end
        RUBY
      )
    end

    it 'identifies OrderItem as a direct dependency of Order' do
      result = analyzer.analyze('Order')
      
      expect(result[:direct_dependencies][:models]).to include('OrderItem')
      expect(result[:transitive_dependencies]).not_to include('OrderItem')
      all_dependencies = result[:direct_dependencies][:models] + result[:transitive_dependencies]
      expect(all_dependencies).to include('OrderItem')
    end
  end

  context "with 'through' and 'source' options in has_many" do
    before do
      create_model_file(
        'post',
        <<~RUBY
          class Post < ApplicationRecord
            has_many :comments
            has_many :commenters, through: :comments, source: :user
          end
        RUBY
      )
      create_model_file(
        'comment',
        <<~RUBY
          class Comment < ApplicationRecord
            belongs_to :post
          end
        RUBY
      )
      create_model_file(
        'user',
        <<~RUBY
          class User < ApplicationRecord
            has_many :comments
          end
        RUBY
      )
    end

    it 'identifies User as a transitive dependency of Post without incorrectly making it direct' do
      result = analyzer.analyze('Post')

      expect(result[:direct_dependencies][:models]).to include('Comment')
      expect(result[:direct_dependencies][:models]).not_to include('User')
      expect(result[:transitive_dependencies]).to include('User')
      all_dependencies = result[:direct_dependencies][:models] + result[:transitive_dependencies]
      expect(all_dependencies).to include('User')
    end
  end

  context "with namespaced models in associations" do
    before do
      create_model_file(
        'account',
        <<~RUBY
          class Account < ApplicationRecord
            belongs_to :admin_user, class_name: "Admin::User"
          end
        RUBY
      )
      create_model_file(
        'admin/user',
        <<~RUBY
          module Admin
            class User < ApplicationRecord
            end
          end
        RUBY
      )
    end

    it 'correctly identifies namespaced models as direct dependencies' do
      result = analyzer.analyze('Account')

      expect(result[:direct_dependencies][:models]).to include('Admin::User')
    end
  end
end
