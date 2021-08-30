source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.6'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.2.3'
# Use Puma as the app server
gem 'puma', '~> 4.3.8'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0.6'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 4.2.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2.2'
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'execjs', '2.7.0' # Newer versions don't work with therubyracer
gem 'therubyracer', '~> 0.12.3', platforms: :ruby
gem 'hyrax', '2.9.5'
gem 'active-fedora', '~> 12.1.1'
gem 'hydra-editor', '5.0.1'
gem 'hydra-role-management', '~> 1.0'
gem 'clamav-client', require: 'clamav/client'
gem 'sidekiq', '~> 5.2.9'
gem 'sidekiq-limit_fetch', '~> 3.4.0'
gem 'sidekiq-status', '~> 2.0.2'
gem 'blacklight_oai_provider', '6.0.0.pre1'
gem 'edtf-humanize', '0.0.7'
gem 'passenger', '5.3.7', require: 'phusion_passenger/rack_handler'
gem 'staccato', '~>0.5.3'
gem 'loofah', '~>2.10.0'
gem "bootstrap-sass", "~> 3.4.1"
gem 'blacklight_range_limit', '6.5.0'
gem 'blacklight_advanced_search', '~> 6.4.1'
gem 'mini_magick', '~>4.9.4'
gem 'roo', '~>2.8.3'
gem 'nokogiri', '~>1.11.7'
gem 'httparty', '~>0.17.3'
gem 'riiif', '~> 2.3.0'
# linkeddata gem is released with rdf gems and should be the same version as rdf
gem 'linkeddata', '~>3.1.1'

# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.4.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5.0.1'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.10.2'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 3.3.0'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'rsolr', '~> 2.0.2'
gem 'devise', '~> 4.8.0'
gem 'devise-guests', '~> 0.7.0'
gem 'omniauth', '~> 1.9.1'
gem 'omniauth-shibboleth', '~> 1.3'

gem 'bulkrax', '~> 1.0.0'
# required by bulkrax_override - rails engine for SWORDv2
gem 'willow_sword', github: 'notch8/willow_sword', ref: '0a669d7'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', '~> 9.1.0', platform: :mri
  gem 'solr_wrapper', '~> 1.1.0'
  gem 'fcrepo_wrapper', '~> 0.8.0'
  gem 'rspec-rails', '~> 3.6.1'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '~> 3.5.1'
  gem 'listen', '~> 3.0.5'
end

group :test do
  gem 'shoulda-matchers', '~> 3.1.3'
  gem 'capybara', '~> 2.17.0'
  gem 'rspec-mocks'
  gem 'webmock', '~> 3.12.2'
  gem 'factory_bot_rails', '~> 6.1.0'
  gem 'simplecov', '~> 0.17.0'
end
