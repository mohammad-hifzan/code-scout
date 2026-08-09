require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'active_support/core_ext/string/inflections'

require_relative '../../lib/indexing/route_mapper'

RSpec.describe RouteMapper do
  let(:project_path) { Dir.mktmpdir }
  after { FileUtils.remove_entry(project_path) }

  subject(:mapper) { described_class.new(project_path) }

  def create_routes_file(content)
    config_path = File.join(project_path, 'config')
    FileUtils.mkdir_p(config_path)
    File.write(File.join(config_path, 'routes.rb'), content)
  end

  describe '#map' do
    context 'when routes.rb is missing' do
      it 'returns an empty array' do
        expect(mapper.map).to be_empty
      end
    end

    context 'when routes.rb is empty' do
      it 'returns an empty array' do
        create_routes_file('')
        expect(mapper.map).to be_empty
      end
    end

    context 'with plural resources' do
      it 'maps a single `resources` declaration' do
        create_routes_file('resources :users')
        expect(mapper.map).to eq([
          { type: 'resource', resource: 'users', controller: 'UsersController' }
        ])
      end

      it 'maps multiple `resources` declarations' do
        create_routes_file(<<~RUBY)
          resources :users
          resources :posts
        RUBY
        expect(mapper.map).to contain_exactly(
          { type: 'resource', resource: 'users', controller: 'UsersController' },
          { type: 'resource', resource: 'posts', controller: 'PostsController' }
        )
      end
    end

    context 'with singular resource' do
      it 'maps a singular `resource` and pluralizes the controller' do
        create_routes_file('resource :profile')
        expect(mapper.map).to eq([
          { type: 'resource', resource: 'profile', controller: 'ProfilesController' }
        ])
      end
    end

    context 'with a root route' do
      it 'maps the root route' do
        create_routes_file('root "home#index"')
        expect(mapper.map).to eq([
          { type: 'root', controller: 'HomeController', action: 'index' }
        ])
      end
    end

    context 'with custom routes' do
      it 'maps routes using the `=>` hash syntax' do
        create_routes_file('get "/rate" => "rater#create"')
        expect(mapper.map).to include(
          { type: 'custom', verb: 'GET', path: '/rate', controller: 'RaterController', action: 'create' }
        )
      end

      it 'maps routes using the `to:` symbol syntax' do
        create_routes_file('get "/search", to: "search#item"')
        expect(mapper.map).to include(
          { type: 'custom', verb: 'GET', path: '/search', controller: 'SearchController', action: 'item' }
        )
      end

      it 'maps different HTTP verbs' do
        create_routes_file(<<~RUBY)
          post "/reviews" => "reviews#create"
          patch "/reviews/:id" => "reviews#update"
          put "/reviews/:id" => "reviews#replace"
          delete "/reviews/:id" => "reviews#destroy"
        RUBY
        expect(mapper.map).to contain_exactly(
          a_hash_including(verb: 'POST', controller: 'ReviewsController', action: 'create'),
          a_hash_including(verb: 'PATCH', controller: 'ReviewsController', action: 'update'),
          a_hash_including(verb: 'PUT', controller: 'ReviewsController', action: 'replace'),
          a_hash_including(verb: 'DELETE', controller: 'ReviewsController', action: 'destroy')
        )
      end
    end

    context 'with namespaced resources' do
      it 'maps a resource inside a single namespace' do
        create_routes_file(<<~RUBY)
          namespace :admin do
            resources :users
          end
        RUBY
        expect(mapper.map).to eq([
          { type: 'resource', resource: 'users', controller: 'Admin::UsersController' }
        ])
      end

      it 'maps a resource inside multiple nested namespaces' do
        create_routes_file(<<~RUBY)
          namespace :api do
            namespace :v1 do
              resources :products
            end
          end
        RUBY
        expect(mapper.map).to eq([
          { type: 'resource', resource: 'products', controller: 'Api::V1::ProductsController' }
        ])
      end

      it 'maps a root route inside a namespace' do
        create_routes_file(<<~RUBY)
          namespace :admin do
            root "dashboard#show"
          end
        RUBY
        expect(mapper.map).to eq([
          { type: 'root', controller: 'Admin::DashboardController', action: 'show' }
        ])
      end
    end

    context 'with devise routes' do
      let(:devise_controllers) do
        %w[
          SessionsController
          RegistrationsController
          PasswordsController
          ConfirmationsController
          UnlocksController
          OmniauthCallbacksController
        ].map do |controller|
          { type: 'devise', controller: controller }
        end
      end

      it 'maps `devise_for :users` to common Devise controllers' do
        create_routes_file('devise_for :users')
        expect(mapper.map).to contain_exactly(*devise_controllers)
      end

      it 'maps `devise_for` for other resources like :admins' do
        create_routes_file('devise_for :admins')
        expect(mapper.map).to contain_exactly(*devise_controllers)
      end

      it 'maps multiple `devise_for` declarations for :admins and :members' do
        create_routes_file(<<~RUBY)
          devise_for :admins
          devise_for :members
        RUBY
        expect(mapper.map.size).to eq(12)
        expect(mapper.map).to include(*devise_controllers)
      end
    end

    context 'with duplicate routes' do
      it 'includes entries for duplicate custom routes' do
        create_routes_file(<<~RUBY)
          get '/search', to: 'search#new'
          get '/search', to: 'search#new'
        RUBY
        expect(mapper.map.count).to eq(2)
        expect(mapper.map).to all(eq({ type: 'custom', verb: 'GET', path: '/search', controller: 'SearchController', action: 'new' }))
      end

      it 'includes entries for duplicate resource routes' do
        create_routes_file(<<~RUBY)
          resources :users
          resources :users
        RUBY
        expect(mapper.map.count).to eq(2)
        expect(mapper.map).to all(eq({ type: 'resource', resource: 'users', controller: 'UsersController' }))
      end
    end

    context 'with route options' do
      it 'extracts the resource when options like `only` are present' do
        create_routes_file('resources :users, only: [:index, :show]')
        expect(mapper.map).to include(
          { type: 'resource', resource: 'users', controller: 'UsersController' }
        )
      end

      it 'extracts the resource when options like `except` are present' do
        create_routes_file('resources :users, except: [:destroy]')
        expect(mapper.map).to include(
          { type: 'resource', resource: 'users', controller: 'UsersController' }
        )
      end
    end

    context 'with formatting variations' do
      it 'handles single quotes for strings' do
        create_routes_file("root 'home#index'")
        expect(mapper.map).to include(
          { type: 'root', controller: 'HomeController', action: 'index' }
        )
      end

      it 'is not affected by extra whitespace' do
        create_routes_file(' resources  :users ')
        expect(mapper.map).to include(
          { type: 'resource', resource: 'users', controller: 'UsersController' }
        )
      end

      it 'handles multiline resource declarations with parentheses' do
        create_routes_file(<<~RUBY)
          resources(
            :posts,
            only: [:index, :show]
          )
        RUBY
        expect(mapper.map).to include(
          { type: 'resource', resource: 'posts', controller: 'PostsController' }
        )
      end

      it 'handles multiline namespace blocks' do
        create_routes_file(<<~RUBY)
          namespace :admin do

            resources :articles

            get 'settings', to: 'settings#index'

          end
        RUBY
        expect(mapper.map).to contain_exactly(
          { type: 'resource', resource: 'articles', controller: 'Admin::ArticlesController' },
          { type: 'custom', verb: 'GET', path: 'settings', controller: 'Admin::SettingsController', action: 'index' }
        )
      end
    end
  end
end
