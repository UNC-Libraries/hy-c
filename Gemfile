source 'https://rubygems.org'
ruby '~> 2.6'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'active-fedora', '~> 12.2'
gem 'blacklight_advanced_search', '~> 6.4.1'
gem 'blacklight_oai_provider', '6.0.0.pre1'
gem 'blacklight_range_limit', '6.5.0'
gem 'bootstrap-sass', '~> 3.4.1'
gem 'bulkrax', '~> 1.0.0'
gem 'clamav-client', require: 'clamav/client'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2.2'
gem 'devise', '~> 4.8.0'
gem 'devise-guests', '~> 0.7.0'
gem 'edtf-humanize', '0.0.7'
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'execjs', '2.8.1'
gem 'httparty', '~>0.20.0'
gem 'hydra-editor', '5.0.1'
gem 'hydra-role-management', '~> 1.0'
gem 'hyrax', '2.9.6'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.11.2'
# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.4.0'
gem 'libv8', '~> 7.3'
# linkeddata gem is released with rdf gems and should be the same version as rdf
gem 'sparql', '3.1.7'
gem 'linkeddata', '~>3.1.1'
gem 'loofah', '~>2.10.0'
gem 'mini_magick', '~>4.9.4'
gem 'mini_racer', '~> 0.2.15', platforms: :ruby
gem 'nokogiri', '~>1.13.4'
gem 'omniauth', '~> 2.0'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-shibboleth', '~> 1.3'
gem 'passenger', '6.0.14', require: 'phusion_passenger/rack_handler'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.2.3'
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.6'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 3.3.0'
gem 'riiif', '~> 2.3.0'
gem 'roo', '~>2.8.3'
gem 'rsolr', '~> 2.0.2'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0.6'
gem 'sidekiq', '~> 5.2.9'
gem 'sidekiq-limit_fetch', '~> 3.4.0'
gem 'sidekiq-status', '~> 2.0.2'
gem 'staccato', '~>0.5.3'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5.0.1'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 4.2.0'
# required by bulkrax_override - rails engine for SWORDv2
gem 'willow_sword', github: 'notch8/willow_sword', ref: '0a669d7'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', '~> 9.1.0', platform: :mri
  gem 'fcrepo_wrapper', '~> 0.8.0'
  gem 'rspec-rails', '~> 3.6.1'
  # Rubocop for style and error checking (linter)
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'solr_wrapper', '~> 1.1.0'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'listen', '~> 3.7.0'
  gem 'puma'
  gem 'web-console', '~> 3.7.0'
end

group :test do
  gem 'capybara', '~> 3.36.0'
  gem 'factory_bot_rails', '~> 6.1.0'
  gem 'ffaker'
  gem 'rspec-mocks'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 5.0.0'
  gem 'simplecov'
  gem 'webdrivers'
  gem 'webmock', '~> 3.14.0'
end
