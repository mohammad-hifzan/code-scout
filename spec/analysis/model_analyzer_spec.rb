require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'active_support/core_ext/string/inflections'

require_relative '../../lib/analysis/model_analyzer'

RSpec.describe ModelAnalyzer do
  subject(:analyzer) { described_class.new }

  let!(:project_path) { Dir.mktmpdir }
  after { FileUtils.remove_entry(project_path) }

  def create_model_file(name, content)
    full_path = File.join(project_path, "#{name}.rb")
    File.write(full_path, content)
    full_path
  end

  describe '#analyze' do
    it 'correctly derives the model name from the path' do
      path = create_model_file('user_profile', 'class UserProfile; end')
      result = analyzer.analyze(path)
      expect(result[:model]).to eq('UserProfile')
    end

    context 'when analyzing an empty file' do
      it 'returns empty results for all categories' do
        path = create_model_file('empty_model', '')
        result = analyzer.analyze(path)
        expect(result[:associations]).to eq({ belongs_to: [], has_many: [], has_one: [] })
        expect(result[:validations]).to be_empty
        expect(result[:callbacks]).to be_empty
        expect(result[:scopes]).to be_empty
        expect(result[:enums]).to be_empty
        expect(result[:includes]).to be_empty
        expect(result[:extends]).to be_empty
      end
    end

    context 'with associations' do
      let(:content) do
        <<~RUBY
          class Post < ApplicationRecord
            has_many :comments
            belongs_to :user
            has_one :main_image, class_name: 'Image'
            has_many :likes, as: :likeable
          end
        RUBY
      end

      it 'extracts all association types' do
        path = create_model_file('post', content)
        result = analyzer.analyze(path)
        associations = result[:associations]
        expect(associations[:has_many]).to contain_exactly(
          { name: 'comments' },
          { name: 'likes' }
        )
        expect(associations[:belongs_to]).to contain_exactly({ name: 'user' })
        expect(associations[:has_one]).to contain_exactly({ name: 'main_image', class_name: 'Image' })
      end
    end

    context 'with association options' do
      let(:content) do
        <<~RUBY
          class Post < ApplicationRecord
            has_many :items, class_name: "OrderItem"
            has_many :commenters, through: :comments, source: :user
            belongs_to :author, class_name: "User"
            has_many :comments
            has_one :profile, class_name: "UserProfile", through: :account
            has_many :tags, through: :taggings
            has_many :readers, through: :subscriptions, source: :user
          end
        RUBY
      end

      it 'extracts class_name option' do
        path = create_model_file('post', content)
        result = analyzer.analyze(path)
        associations = result[:associations]

        has_many = associations[:has_many]
        expect(has_many).to include({ name: 'items', class_name: 'OrderItem' })
        expect(has_many).to include({ name: 'comments' })
        expect(has_many).to include({ name: 'tags', through: 'taggings' })
        expect(has_many).to include({ name: 'readers', through: 'subscriptions', source: 'user' })

        belongs_to = associations[:belongs_to]
        expect(belongs_to).to include({ name: 'author', class_name: 'User' })

        has_one = associations[:has_one]
        expect(has_one).to include({ name: 'profile', class_name: 'UserProfile', through: 'account' })
      end

      it 'extracts through option alone' do
        path = create_model_file('post', content)
        result = analyzer.analyze(path)
        associations = result[:associations]

        has_many = associations[:has_many]
        tags_assoc = has_many.find { |a| a[:name] == 'tags' }
        expect(tags_assoc).to eq({ name: 'tags', through: 'taggings' })
      end

      it 'extracts through and source together' do
        path = create_model_file('post', content)
        result = analyzer.analyze(path)
        associations = result[:associations]

        has_many = associations[:has_many]
        commenters_assoc = has_many.find { |a| a[:name] == 'commenters' }
        readers_assoc = has_many.find { |a| a[:name] == 'readers' }

        expect(commenters_assoc).to eq({ name: 'commenters', through: 'comments', source: 'user' })
        expect(readers_assoc).to eq({ name: 'readers', through: 'subscriptions', source: 'user' })
      end

      it 'does not add keys for absent options on normal associations' do
        path = create_model_file('post', content)
        result = analyzer.analyze(path)
        associations = result[:associations]

        comments_assoc = associations[:has_many].find { |a| a[:name] == 'comments' }
        expect(comments_assoc).to eq({ name: 'comments' })
        expect(comments_assoc).not_to have_key(:class_name)
        expect(comments_assoc).not_to have_key(:through)
        expect(comments_assoc).not_to have_key(:source)
      end

      it 'handles multiple associations with different options' do
        path = create_model_file('post', content)
        result = analyzer.analyze(path)
        associations = result[:associations]

        # All associations should be present
        expect(associations[:has_many].size).to eq(5)
        expect(associations[:belongs_to].size).to eq(1)
        expect(associations[:has_one].size).to eq(1)
      end
    end

    context 'with multiple associations of the same type' do
      let(:content) do
        <<~RUBY
          class User < ApplicationRecord
            has_many :posts
            has_many :articles
          end
        RUBY
      end

      it 'extracts all has_many associations' do
        path = create_model_file('user', content)
        result = analyzer.analyze(path)
        expect(result[:associations][:has_many]).to contain_exactly(
          { name: 'posts' },
          { name: 'articles' }
        )
      end
    end

    context 'with validations' do
      let(:content) do
        <<~RUBY
          class Account < ApplicationRecord
            validates :name, presence: true, uniqueness: { case_sensitive: false }
            validates :subdomain, format: { with: /\A[a-zA-Z0-9]+\z/ }
            validates :owner_id, on: :create
          end
        RUBY
      end

      it 'extracts validated fields without including option values' do
        path = create_model_file('account', content)
        result = analyzer.analyze(path)
        expect(result[:validations]).to contain_exactly('name', 'subdomain', 'owner_id')
      end
    end

    context 'with callbacks' do
      let(:content) do
        <<~RUBY
          class User < ApplicationRecord
            before_validation :set_defaults
            before_save :normalize_email
            after_commit :send_welcome_email
            around_save :time_save
          end
        RUBY
      end

      it 'extracts all callback types' do
        path = create_model_file('user', content)
        result = analyzer.analyze(path)
        expect(result[:callbacks]).to contain_exactly('set_defaults', 'normalize_email', 'send_welcome_email', 'time_save')
      end
    end

    context 'with scopes' do
      let(:content) do
        <<~RUBY
          class Article < ApplicationRecord
            scope :published, -> { where(published: true) }
            scope :recent, -> { order(created_at: :desc).limit(5) }
            pg_search_scope :search_by_title, against: :title
          end
        RUBY
      end

      it 'extracts names of both standard and pg_search scopes' do
        path = create_model_file('article', content)
        result = analyzer.analyze(path)
        expect(result[:scopes]).to contain_exactly('published', 'recent', 'search_by_title')
      end
    end

    context 'with enums' do
      let(:content) do
        <<~RUBY
          class Order < ApplicationRecord
            enum :status, [ :pending, :processing, :shipped ]
            enum :payment_method, { credit_card: 0, paypal: 1 }
          end
        RUBY
      end

      it 'extracts enum attribute names' do
        path = create_model_file('order', content)
        result = analyzer.analyze(path)
        expect(result[:enums]).to contain_exactly('status', 'payment_method')
      end
    end

    context 'with includes and extends' do
      let(:content) do
        <<~RUBY
          class AdminUser < User
            include Auditable
            include Namespace::Concerns::Qualifiable
            extend ClassMethods
          end
        RUBY
      end

      it 'extracts the names of included and extended modules' do
        path = create_model_file('admin_user', content)
        result = analyzer.analyze(path)
        expect(result[:includes]).to contain_exactly('Auditable', 'Namespace::Concerns::Qualifiable')
        expect(result[:extends]).to contain_exactly('ClassMethods')
      end
    end

    context 'with multiline syntax' do
      let(:content) do
        <<~RUBY
          class Product < ApplicationRecord
            has_many(
              :reviews,
              class_name: "ProductReview",
              foreign_key: "product_id"
            )

            validates :name,
              presence: true,
              length: { minimum: 2 }
          end
        RUBY
      end

      it 'correctly parses multiline definitions' do
        path = create_model_file('product', content)
        result = analyzer.analyze(path)
        expect(result[:associations][:has_many]).to contain_exactly(
          { name: 'reviews', class_name: 'ProductReview' }
        )
        expect(result[:validations]).to contain_exactly('name')
      end
    end
  end
end
