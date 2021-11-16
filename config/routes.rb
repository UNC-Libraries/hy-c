Rails.application.routes.draw do
  mount Bulkrax::Engine, at: '/'
  # mount BrowseEverything::Engine => '/browse'
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  mount Riiif::Engine => 'images', as: :riiif if Hyrax.config.iiif_image_server?

  get 'accounts/new', to: 'accounts#new'
  post 'accounts/create', to: 'accounts#create'

  match "/404", :to => "errors#not_found", :via => :all
  match "/500", :to => "errors#internal_server_error", :via => :all

  resources :default_admin_sets, except: :show
  get 'masters_papers/department', to: 'masters_papers#department'
  post 'masters_papers/select_department', to: 'masters_papers#select_department'

  concern :oai_provider, BlacklightOaiProvider::Routes.new

  authenticate :user, ->(u) { u.admin? } do
    require 'sidekiq/web'
    require 'sidekiq-status/web'
    mount Sidekiq::Web => '/sidekiq'
  end

  # [hyc-override] Remove blacklight routes, e.g. suggest, saved_searches, search_history
  match 'search_history', to: 'errors#not_found', via: :all
  match 'saved_searches', to: 'errors#not_found', via: :all
  get 'suggest', to: 'errors#not_found'

  mount Blacklight::Engine => '/'
  mount BlacklightAdvancedSearch::Engine => '/'

  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :oai_provider
    concerns :searchable
    concerns :range_searchable
  end

  devise_for :users, controllers: { sessions: "omniauth", omniauth_callbacks: "omniauth_callbacks" }

  # Disable these routes if you are using Devise's
  # database_authenticatable in your development environment.
  unless AuthConfig.use_database_auth?
    devise_scope :user do
      get 'sign_in', to: 'omniauth#new', as: :new_user_session
      post 'sign_in', to: 'omniauth_callbacks#shibboleth', as: :new_session
      get 'sign_out', to: 'omniauth#destroy', as: :destroy_user_session
    end
  end

  mount Hydra::RoleManagement::Engine => '/'

  mount Qa::Engine => '/authorities'
  mount Hyrax::Engine, at: '/'
  resources :welcome, only: 'index'
  root 'hyrax/homepage#index'
  curation_concerns_basic_routes
  concern :exportable, Blacklight::Routes::Exportable.new

  # [hyc-override] Remove routes we don't use e.g. catalog email and sms routes
  # we need this for accessing ttl files
  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog'

  # resources :bookmarks do
  #   concerns :exportable
  #
  #   collection do
  #     delete 'clear'
  #   end
  # end

  # Catch all route for any routes that don't exist. Always have this as the last route
  match "*path", to: "errors#not_found", via: :all, format: false, defaults: { format: 'html' }

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
