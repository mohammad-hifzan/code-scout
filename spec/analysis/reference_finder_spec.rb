require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require_relative '../../lib/analysis/reference_finder'

RSpec.describe ReferenceFinder do
  let(:project_path) { @project_path }
  let(:finder) { described_class.new(project_path) }

  around do |example|
    Dir.mktmpdir do |dir|
      @project_path = dir
      example.run
    end
  end

  def create_file(path, content)
    full_path = File.join(project_path, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  describe '#find' do
    context 'with direct constant references' do
      before do
        create_file('app/models/user.rb', 'class User < ApplicationRecord; end')
        create_file('app/controllers/users_controller.rb', 'class UsersController < ApplicationController; def index; User.all; end; end')
      end

      it 'finds references to the constant' do
        result = finder.find('User')
        expect(result).to include(a_string_ending_with('app/models/user.rb'))
        expect(result).to include(a_string_ending_with('app/controllers/users_controller.rb'))
      end
    end

    context 'with .new and class methods' do
      before do
        create_file('app/services/user_creator.rb', 'class UserCreator; def create; User.new; end; end')
        create_file('app/jobs/user_job.rb', 'class UserJob; def perform; User.some_class_method; end; end')
      end

      it 'finds references in .new and class method calls' do
        result = finder.find('User')
        expect(result).to include(a_string_ending_with('app/services/user_creator.rb'))
        expect(result).to include(a_string_ending_with('app/jobs/user_job.rb'))
      end
    end

    context 'with namespaced constants' do
      before do
        create_file('app/models/admin/user.rb', 'class Admin::User < ApplicationRecord; end')
        create_file('app/controllers/admin/users_controller.rb', 'class Admin::UsersController < ApplicationController; Admin::User.find(1); end')
      end

      it 'finds references to namespaced constants' do
        result = finder.find('Admin::User')
        expect(result).to include(a_string_ending_with('app/models/admin/user.rb'))
        expect(result).to include(a_string_ending_with('app/controllers/admin/users_controller.rb'))
      end
    end

    context 'with multiple references in multiple files' do
      before do
        create_file('app/models/post.rb', 'class Post; end')
        create_file('app/controllers/posts_controller.rb', 'class PostsController; Post.all; Post.first; end')
        create_file('app/views/posts/index.html.erb', '<%= Post.count %>')
      end

      it 'returns each file only once' do
        result = finder.find('Post')
        expect(result.count).to eq(3)
        expect(result).to include(a_string_ending_with('app/models/post.rb'))
        expect(result).to include(a_string_ending_with('app/controllers/posts_controller.rb'))
        expect(result).to include(a_string_ending_with('app/views/posts/index.html.erb'))
      end
    end

    context 'with references in comments and strings' do
      before do
        create_file('app/models/item.rb', <<~RUBY)
          class Item
            # Do not use User here
            def a_method
              "A string about a User"
            end
          end
        RUBY
      end

      it 'does not count references in comments or strings' do
        result = finder.find('User')
        expect(result).to be_empty
      end
    end

    context 'with similarly named constants' do
      before do
        create_file('app/models/user.rb', 'class User; end')
        create_file('app/models/user_profile.rb', 'class UserProfile; end')
        create_file('app/services/abuser_reporter.rb', 'class AbuserReporter; end')
        create_file('app/models/super_user.rb', 'class SuperUser < User; end')
      end

      it 'only finds references to the exact constant' do
        result = finder.find('User')
        expect(result).to include(a_string_ending_with('app/models/user.rb'))
        expect(result).to include(a_string_ending_with('app/models/super_user.rb')) # SuperUser is a User
        expect(result).not_to include(a_string_ending_with('app/models/user_profile.rb'))
        expect(result).not_to include(a_string_ending_with('app/services/abuser_reporter.rb'))
      end
    end

    context 'with ERB / view references' do
      before do
        create_file('app/views/users/show.html.erb', '<h1><%= User.name %></h1>')
      end

      it 'finds references in ERB files' do
        result = finder.find('User')
        expect(result).to include(a_string_ending_with('app/views/users/show.html.erb'))
      end
    end

    context 'with multiline and namespaced valid formatting' do
      before do
        create_file('app/models/user.rb', 'class User; end')
        create_file('app/controllers/users_controller.rb', <<~RUBY)
          class UsersController
            def show
              ::User
                .includes(:posts)
                .find(params[:id])
            end
          end
        RUBY
        create_file('app/models/user_profile.rb', 'class UserProfile; end')
        create_file('app/models/super_user.rb', 'class SuperUser < User; end')
      end

      it 'matches exact constants without substring false positives' do
        result = finder.find('User')
        expect(result).to include(a_string_ending_with('app/models/user.rb'))
        expect(result).to include(a_string_ending_with('app/controllers/users_controller.rb'))
        expect(result).not_to include(a_string_ending_with('app/models/user_profile.rb'))
      end
    end

    context 'with empty files or projects' do
      it 'handles empty files' do
        create_file('app/models/empty.rb', '')
        expect(finder.find('User')).to be_empty
      end

      it 'handles empty projects' do
        expect(finder.find('User')).to be_empty
      end
    end

    context 'with non-existent paths' do
      it 'handles non-existent paths gracefully' do
        finder = described_class.new('/non/existent/path')
        expect(finder.find('User')).to be_empty
      end
    end
  end
end
