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
    path = File.join(project_path, 'app', 'models')
    FileUtils.mkdir_p(path)
    full_path = File.join(path, "#{name}.rb")
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

    it 'fails to identify OrderItem as a dependency of Order' do
      result = analyzer.analyze('Order')
      
      # The current, incorrect implementation will likely resolve :items to "Item".
      # "Item" doesn't exist, so the dependency will be missed.
      # We assert that the correct dependency, "OrderItem", is found.
      # This test will fail, demonstrating the gap.
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

    it 'fails to identify User as a dependency of Post through :commenters' do
      result = analyzer.analyze('Post')

      # The current, incorrect implementation will resolve :commenters to "Commenter".
      # "Commenter" doesn't exist.
      # We assert that the correct dependency, "User", is found.
      # This test will fail.
      #
      # The dependency on User might be found via Comment -> User, but we
      # want to prove that the `through/source` path is broken.
      # The assertion is on the total dependency set.
      all_dependencies = result[:direct_dependencies][:models] + result[:transitive_dependencies]
      expect(all_dependencies).to include('User')
    end
  end
end
