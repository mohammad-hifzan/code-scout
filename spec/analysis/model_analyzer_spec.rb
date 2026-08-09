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
        expect(associations[:has_many]).to contain_exactly('comments', 'likes')
        expect(associations[:belongs_to]).to contain_exactly('user')
        expect(associations[:has_one]).to contain_exactly('main_image')
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
        expect(result[:associations][:has_many]).to contain_exactly('posts', 'articles')
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
        expect(result[:associations][:has_many]).to contain_exactly('reviews')
        expect(result[:validations]).to contain_exactly('name')
      end
    end
  end
end
