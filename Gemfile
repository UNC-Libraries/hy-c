# frozen_string_literal: true
source 'https://rubygems.org'
ruby '~> 2.7.4'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'active-fedora', '~> 13.1'
gem 'blacklight_advanced_search', '~> 6.4.1'
gem 'blacklight_oai_provider', '6.1.1'
gem 'blacklight_range_limit', '6.5.0'
gem 'bootstrap-sass', '~> 3.4.1'
gem 'bulkrax', '~> 5.0.0'
gem 'clamav-client', require: 'clamav/client'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2.2'
gem 'devise', '~> 4.8.0'
gem 'devise-guests', '~> 0.8.1'
gem 'edtf-humanize', '2.0.1'
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'execjs', '2.8.1'
gem 'httparty', '~>0.21.0'
gem 'hydra-editor', '~> 5.0'
gem 'hydra-role-management', '~> 1.0'
gem 'hyrax', :git => 'https://github.com/bbpennel/hyrax.git', :ref => 'ae32b4e6'
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
gem 'mini_magick', '~>4.11.0'
gem 'mini_racer', '~> 0.2.15', platforms: :ruby
gem 'nokogiri', '~>1.14.2'
gem 'omniauth', '~> 2.0'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-shibboleth', '~> 1.3'
gem 'passenger', '6.0.14', require: 'phusion_passenger/rack_handler'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.3.5'
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.8.1'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.5.0'
gem 'riiif', '~> 2.4.0'
gem 'roo', '~>2.9.0'
gem 'rsolr', '~> 2.5.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.1.0'
gem 'sidekiq', '~> 5.2.10'
gem 'sidekiq-status', '~> 2.1.3'
gem 'staccato', '~>0.5.3'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5.2.1'
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
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 5.1.0'
  gem 'simplecov'
  gem 'webdrivers'
  gem 'webmock', '~> 3.14.0'
end
