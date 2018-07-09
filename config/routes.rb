Rails.application.routes.draw do
  resources :default_admin_sets, except: :show
  get 'masters_papers/department', to: 'masters_papers#department'
  post 'masters_papers/select_department', to: 'masters_papers#select_department'

  concern :oai_provider, BlacklightOaiProvider::Routes.new

  require 'sidekiq/web'
  require 'constraint/is_unc_admin'

  # Restrict to admins
  mount Sidekiq::Web => '/sidekiq', :constraints => Constraint::IsUncAdmin.new

  
  mount Blacklight::Engine => '/'
  
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :oai_provider
    concerns :searchable
  end

  devise_for :users
  mount Hydra::RoleManagement::Engine => '/'

  mount Qa::Engine => '/authorities'
  mount Hyrax::Engine, at: '/'
  resources :welcome, only: 'index'
  root 'hyrax/homepage#index'
  curation_concerns_basic_routes
  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
