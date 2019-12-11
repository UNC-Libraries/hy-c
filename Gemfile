source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.0.7.2'
# Use postgresql as the database for Active Record
gem 'pg', '~> 0.21.0'
# Use Puma as the app server
gem 'puma', '~> 3.12.2'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0.6'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 3.2.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2.2'
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer', '~> 0.12.3', platforms: :ruby
gem 'hyrax', '2.6.0'
gem 'hydra-editor', '4.0.1'
gem 'hydra-role-management', '~> 1.0'
gem 'clamby', '~> 1.5.1'
gem 'sidekiq', '~> 5.0.4'
gem 'sidekiq-limit_fetch', '~> 3.4.0'
gem 'sidekiq-status', '~> 1.1.1'
gem 'blacklight_oai_provider', '6.0.0.pre1'
gem 'edtf-humanize', '0.0.7'
gem 'passenger', '5.3.7', require: 'phusion_passenger/rack_handler'
gem 'staccato', '~>0.5.1'
gem 'loofah', '~>2.3.1'
gem "bootstrap-sass", "~> 3.4.1"
gem 'blacklight_range_limit', '6.3.3'
gem 'blacklight_advanced_search', '~> 6.4.1'
gem 'mini_magick', '~>4.9.4'
gem 'roo', '~>2.8.2'
gem 'nokogiri', '~>1.10.4'
gem 'httparty', '~>0.17.1'

# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.3.1'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5.0.1'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7.0'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 3.3.0'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'rsolr', '~> 2.0.2'
gem 'devise', '~> 4.7.1'
gem 'devise-guests', '~> 0.6.0'
gem 'omniauth-shibboleth', '~> 1.3'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', '~> 9.1.0', platform: :mri
  gem 'solr_wrapper', '~> 1.1.0'
  gem 'fcrepo_wrapper', '~> 0.8.0'
  gem 'rspec-rails', '~> 3.6.0'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '~> 3.5.1'
  gem 'listen', '~> 3.0.5'
end

group :test do
  gem 'shoulda-matchers', '~> 3.1.2'
  gem 'capybara', '~> 2.17.0'
  gem 'rspec-mocks'
  gem 'webmock'
  gem 'factory_bot_rails', '~> 5.0.1'
  gem 'simplecov', '~> 0.17.0'
end

gem 'riiif', '~> 2.0'
