#!/bin/bash

source scl_source enable rh-ruby26
source scl_source enable devtoolset-8

mkdir -p /opt/hyrax/log/
bundle check || bundle install
# The bundle config and package are needed for the odd way we manage gems in production
bundle config --local cache_path /hyc-gems
bundle package
find . -name *.pid -delete
bundle exec rake tmp:cache:clear
bundle exec rake db:create && bundle exec rake db:migrate
bundle exec rake setup:admin_role
bundle exec rails hyrax:default_collection_types:create
bundle exec rails hyrax:default_admin_set:create
bundle exec sidekiq --daemon
bundle exec puma -C config/puma.rb
