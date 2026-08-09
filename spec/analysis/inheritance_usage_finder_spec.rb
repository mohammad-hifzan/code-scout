# frozen_string_literal: true
require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'analysis/inheritance_usage_finder'

RSpec.describe InheritanceUsageFinder do
  let(:project_path) { Dir.mktmpdir }
  let(:project_map) do
    {
      models: {
        'Post' => { path: File.join(project_path, 'app/models/post.rb') },
        'Article' => { path: File.join(project_path, 'app/models/article.rb') },
        'Admin::Post' => { path: File.join(project_path, 'app/models/admin/post.rb') },
        'Content::BasePost' => { path: File.join(project_path, 'app/models/content/base_post.rb') }
      },
      controllers: {
        'PostsController' => { path: File.join(project_path, 'app/controllers/posts_controller.rb') },
        'BaseController' => { path: File.join(project_path, 'app/controllers/base_controller.rb') }
      },
      views: {}
    }
  end

  subject(:finder) { described_class.new(project_path, project_map) }

  before do
    FileUtils.mkdir_p(File.join(project_path, 'app/models/admin'))
    FileUtils.mkdir_p(File.join(project_path, 'app/models/content'))
    FileUtils.mkdir_p(File.join(project_path, 'app/controllers'))
  end

  after do
    FileUtils.remove_entry(project_path)
  end

  def write_file(path, content)
    File.write(File.join(project_path, path), content)
  end

  describe '#used_classes' do
    it 'returns an empty array when there is no inheritance' do
      write_file('app/models/article.rb', 'class Article; end')
      expect(finder.used_classes).to be_empty
    end

    it 'finds a model used as a parent class' do
      write_file('app/models/post.rb', 'class Post; end')
      write_file('app/models/article.rb', 'class Article < Post; end')
      expect(finder.used_classes).to contain_exactly('Post')
    end

    it 'finds a controller used as a parent class' do
      write_file('app/controllers/base_controller.rb', 'class BaseController; end')
      write_file('app/controllers/posts_controller.rb', 'class PostsController < BaseController; end')
      expect(finder.used_classes).to contain_exactly('BaseController')
    end

    context 'with namespaced inheritance' do
      it 'correctly identifies a namespaced parent class' do
        write_file('app/models/content/base_post.rb', 'class Content::BasePost; end')
        write_file('app/models/admin/post.rb', 'class Admin::Post < Content::BasePost; end')
        expect(finder.used_classes).to contain_exactly('Content::BasePost')
      end
    end
    
    it 'handles multiple levels of inheritance (STI-style)' do
        write_file('app/models/post.rb', 'class Post; end')
        write_file('app/models/article.rb', 'class Article < Post; end')
        write_file('app/models/special_article.rb', 'class SpecialArticle < Article; end')
        expect(finder.used_classes).to contain_exactly('Post', 'Article')
    end

    it 'ignores ApplicationRecord and ApplicationController' do
        write_file('app/models/post.rb', 'class Post < ApplicationRecord; end')
        write_file('app/controllers/posts_controller.rb', 'class PostsController < ApplicationController; end')
        expect(finder.used_classes).to be_empty
    end

    it 'only returns classes that are known in the project map' do
        write_file('app/models/post.rb', 'class Post < SomeGem::Base; end')
        expect(finder.used_classes).to be_empty
    end
    
    it 'returns a unique list of parent classes' do
        write_file('app/models/post.rb', 'class Post; end')
        write_file('app/models/article.rb', 'class Article < Post; end')
        write_file('app/models/comment.rb', 'class Comment < Post; end')
        expect(finder.used_classes).to contain_exactly('Post')
    end
  end
end