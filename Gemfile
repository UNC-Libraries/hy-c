# frozen_string_literal: true
source 'https://rubygems.org'
ruby '~> 2.7.4'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'active-fedora', '~> 14.0'
gem 'blacklight_advanced_search', '~> 7.0.0'
gem 'blacklight_oai_provider', '7.0.2'
gem 'blacklight_range_limit', '8.2.3 '
gem 'bootstrap', '~> 4.0'
gem 'bulkrax', '~> 5.0'
gem 'clamav-client', require: 'clamav/client'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 5.0.0'
gem 'devise', '~> 4.8.0'
gem 'devise-guests', '~> 0.8.1'
gem 'edtf-humanize', '2.0.1'
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'execjs', '2.8.1'
gem 'httparty', '~>0.21.0'
gem 'hydra-editor', '~> 6.0'
gem 'hydra-role-management', '~> 1.0'
gem 'hyrax', git: 'https://github.com/UNC-Libraries/hyrax.git', branch: 'unc-hyrax-4-development'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.11.2'
# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.5.0'
gem 'json-ld', '< 3.2'
gem 'libv8', '~> 7.3'
# linkeddata gem is released with rdf gems and should be the same version as rdf
gem 'sparql', '3.2.5'
gem 'linkeddata'
gem 'loofah', '~>2.19.1'
gem 'mini_magick', '~>4.12.0'
gem 'mini_racer', '~> 0.2.15', platforms: :ruby
gem 'nokogiri', '~>1.14.2'
gem 'omniauth', '~> 2.0'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-shibboleth', '~> 1.3'
gem 'passenger', '6.0.14', require: 'phusion_passenger/rack_handler'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.3.5'
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.5.0'
gem 'riiif', '~> 2.4.0'
gem 'roo', '~>2.9.0'
gem 'rsolr', '~> 2.5.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 6.0.0'
gem 'sidekiq', '~> 6.0'
gem 'sidekiq-status', '~> 3.0.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5.2.1'
gem 'twitter-typeahead-rails', '0.11.1.pre.corejavascript'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 4.2.0'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', '~> 11.1.3', platform: :mri
  gem 'fcrepo_wrapper', '~> 0.9.0'
  gem 'rspec-rails', '~> 5.1.2'
  # Rubocop for style and error checking (linter)
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'solr_wrapper', '~> 4.0.2'
  gem 'rubocop-github'
  gem 'rubocop-performance', require: false
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'listen', '~> 3.7.0'
  gem 'puma'
  gem 'web-console', '~> 3.7.0'
end

group :test do
  gem 'capybara', '~> 3.36'
  gem 'factory_bot_rails', '~> 6.2.0'
  gem 'ffaker'
  gem 'rspec-mocks'
  gem 'selenium-webdriver', '~> 4.8'
  gem 'shoulda-matchers', '~> 5.1.0'
  gem 'simplecov'
  gem 'webdrivers'
  gem 'webmock', '~> 3.14.0'
end
