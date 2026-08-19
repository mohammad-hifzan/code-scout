require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require_relative '../../lib/graph/graph_builder'
require_relative '../../lib/indexing/project_mapper'

RSpec.describe GraphBuilder do
  subject(:builder) { described_class.new(project_map) }

  let!(:project_path) { Dir.mktmpdir }
  after { FileUtils.remove_entry(project_path) }
  let(:project_map) { ProjectMapper.new(project_path).map }

  def create_model_file(name, content)
    path = File.join(project_path, 'app', 'models')
    FileUtils.mkdir_p(path)
    full_path = File.join(path, "#{name}.rb")
    File.write(full_path, content)
  end

  before do
    create_model_file('application_record', 'class ApplicationRecord; end')
  end

  describe '#build' do
    context "with a 'class_name' option" do
      before do
        create_model_file('order', <<~RUBY)
          class Order < ApplicationRecord
            has_many :items, class_name: "OrderItem"
          end
        RUBY
        create_model_file('order_item', <<~RUBY)
          class OrderItem < ApplicationRecord
            belongs_to :order
          end
        RUBY
      end

      it 'resolves the dependency using the class_name' do
        graph = builder.build('Order')
        order_item_node = graph[:associations][:has_many].first
        expect(order_item_node[:model]).to eq('OrderItem')
      end
    end

    context 'with a standard has_many association' do
      before do
        create_model_file('user', <<~RUBY)
          class User < ApplicationRecord
            has_many :posts
          end
        RUBY
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            belongs_to :user
          end
        RUBY
      end

      it 'resolves the plural name and includes the model' do
        graph = builder.build('User')
        post_node = graph[:associations][:has_many].first
        expect(post_node[:model]).to eq('Post')
      end
    end

    context 'with nested dependencies' do
      before do
        create_model_file('user', <<~RUBY)
          class User < ApplicationRecord
            has_many :posts
          end
        RUBY
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            has_many :comments
          end
        RUBY
        create_model_file('comment', 'class Comment < ApplicationRecord; end')
      end

      it 'returns a deeply nested graph' do
        graph = builder.build("User")
        post_node = graph[:associations][:has_many].first
        expect(post_node[:model]).to eq("Post")
        comment_node = post_node[:associations][:has_many].first
        expect(comment_node[:model]).to eq("Comment")
      end
    end

    context 'with a circular dependency' do
      before do
        create_model_file('user', <<~RUBY)
          class User < ApplicationRecord
            has_many :posts
          end
        RUBY
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            belongs_to :user
          end
        RUBY
      end

      it 'terminates and does not recurse infinitely' do
        graph = builder.build("User")
        post_node = graph[:associations][:has_many].first
        expect(post_node[:model]).to eq("Post")
        expect(post_node[:associations][:belongs_to]).to be_empty
      end
    end
  end
end
