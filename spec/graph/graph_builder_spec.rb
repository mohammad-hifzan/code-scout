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

    context 'with namespaced associations' do
      before do
        FileUtils.mkdir_p(File.join(project_path, 'app', 'models', 'billing'))
        create_model_file('billing/invoice', <<~RUBY)
          class Billing::Invoice < ApplicationRecord
            belongs_to :customer
          end
        RUBY
        create_model_file('billing/customer', <<~RUBY)
          class Billing::Customer < ApplicationRecord
          end
        RUBY
      end

      it 'resolves the association relative to the namespace' do
        graph = builder.build('Billing::Invoice')
        customer_node = graph[:associations][:belongs_to].first
        expect(customer_node[:model]).to eq('Billing::Customer')
      end
    end

    context "with 'through' without explicit join association (implicit through model)" do
      before do
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            has_many :tags, through: :taggings
          end
        RUBY
        create_model_file('tagging', <<~RUBY)
          class Tagging < ApplicationRecord
            belongs_to :post
            belongs_to :tag
          end
        RUBY
        create_model_file('tag', <<~RUBY)
          class Tag < ApplicationRecord
            has_many :taggings
          end
        RUBY
      end

      it 'traverses both the implicit through model and the target model' do
        graph = builder.build('Post')
        has_many_models = graph[:associations][:has_many].map { |n| n[:model] }
        expect(has_many_models).to contain_exactly('Tagging', 'Tag')
      end
    end

    context "with 'through' when through model is already declared explicitly" do
      before do
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            has_many :taggings
            has_many :tags, through: :taggings
          end
        RUBY
        create_model_file('tagging', <<~RUBY)
          class Tagging < ApplicationRecord
            belongs_to :post
            belongs_to :tag
          end
        RUBY
        create_model_file('tag', <<~RUBY)
          class Tag < ApplicationRecord
            has_many :taggings
          end
        RUBY
      end

      it 'includes the through model only once without creating duplicate sibling nodes' do
        graph = builder.build('Post')
        has_many_models = graph[:associations][:has_many].map { |n| n[:model] }
        expect(has_many_models).to eq(['Tagging', 'Tag'])
      end
    end

    context "with 'through' when through model does not exist" do
      before do
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            has_many :tags, through: :taggings
          end
        RUBY
        create_model_file('tag', <<~RUBY)
          class Tag < ApplicationRecord
          end
        RUBY
      end

      it 'gracefully includes only the reachable target model without crashing' do
        graph = builder.build('Post')
        has_many_models = graph[:associations][:has_many].map { |n| n[:model] }
        expect(has_many_models).to contain_exactly('Tag')
      end
    end

    context "with 'through' and 'source' options" do
      before do
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            has_many :comments
            has_many :commenters, through: :comments, source: :user
          end
        RUBY
        create_model_file('comment', <<~RUBY)
          class Comment < ApplicationRecord
            belongs_to :post
          end
        RUBY
        create_model_file('user', <<~RUBY)
          class User < ApplicationRecord
            has_many :comments
          end
        RUBY
      end

      it 'resolves both through and source dependencies without duplicating Comment' do
        graph = builder.build('Post')
        has_many_models = graph[:associations][:has_many].map { |n| n[:model] }
        expect(has_many_models).to eq(['Comment', 'User'])
      end
    end

    context 'with namespaced through and source associations' do
      before do
        FileUtils.mkdir_p(File.join(project_path, 'app', 'models', 'billing'))
        create_model_file('billing/invoice', <<~RUBY)
          class Billing::Invoice < ApplicationRecord
            has_many :transactions, through: :payments, source: :record
          end
        RUBY
        create_model_file('billing/payment', <<~RUBY)
          class Billing::Payment < ApplicationRecord
          end
        RUBY
        create_model_file('billing/record', <<~RUBY)
          class Billing::Record < ApplicationRecord
          end
        RUBY
      end

      it 'resolves both namespaced through and source models' do
        graph = builder.build('Billing::Invoice')
        has_many_models = graph[:associations][:has_many].map { |n| n[:model] }
        expect(has_many_models).to eq(['Billing::Payment', 'Billing::Record'])
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

    context 'with polymorphic belongs_to association' do
      before do
        create_model_file('picture', <<~RUBY)
          class Picture < ApplicationRecord
            belongs_to :imageable, polymorphic: true
          end
        RUBY
      end

      it 'does not create a graph node for the polymorphic interface and does not raise' do
        graph = builder.build('Picture')
        expect(graph[:model]).to eq('Picture')
        expect(graph[:associations][:belongs_to]).to be_empty
      end
    end

    context 'with polymorphic belongs_to when a model with the interface name exists in the project' do
      before do
        create_model_file('picture', <<~RUBY)
          class Picture < ApplicationRecord
            belongs_to :imageable, polymorphic: true
          end
        RUBY
        create_model_file('imageable', <<~RUBY)
          class Imageable < ApplicationRecord
          end
        RUBY
      end

      it 'does not traverse the Imageable model for the polymorphic association' do
        graph = builder.build('Picture')
        expect(graph[:associations][:belongs_to]).to be_empty
      end
    end

    context 'with has_many using as: option' do
      before do
        create_model_file('post', <<~RUBY)
          class Post < ApplicationRecord
            has_many :pictures, as: :imageable
          end
        RUBY
        create_model_file('picture', <<~RUBY)
          class Picture < ApplicationRecord
            belongs_to :imageable, polymorphic: true
          end
        RUBY
      end

      it 'traverses the target model without creating an Imageable node' do
        graph = builder.build('Post')
        has_many_nodes = graph[:associations][:has_many]
        expect(has_many_nodes.map { |n| n[:model] }).to contain_exactly('Picture')
        picture_node = has_many_nodes.first
        expect(picture_node[:associations][:belongs_to]).to be_empty
      end
    end

    context 'with mixed polymorphic and concrete associations' do
      before do
        create_model_file('picture', <<~RUBY)
          class Picture < ApplicationRecord
            belongs_to :imageable, polymorphic: true
            has_many :tags
          end
        RUBY
        create_model_file('tag', <<~RUBY)
          class Tag < ApplicationRecord
          end
        RUBY
      end

      it 'traverses only the statically resolvable concrete associations' do
        graph = builder.build('Picture')
        expect(graph[:associations][:belongs_to]).to be_empty
        expect(graph[:associations][:has_many].map { |n| n[:model] }).to contain_exactly('Tag')
      end
    end
  end
end
