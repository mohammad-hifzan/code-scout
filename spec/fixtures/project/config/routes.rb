Rails.application.routes.draw do
  resources :users
  resources :posts, only: [:index, :show]
  namespace :admin do
    resources :dashboard, only: [:index]
  end
  get '/home', to: 'home#index'

  # A duplicate route to test uniq
  get '/users', to: 'users#index'
end
