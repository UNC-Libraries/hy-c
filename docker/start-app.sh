#!/bin/bash

echo 'source /opt/rh/rh-ruby26/enable' >> ~/.bashrc
source /opt/rh/rh-ruby26/enable
bundle check || bundle install
# The bundle config and package are needed for the odd way we manage gems in production
bundle config --local cache_path /hyc-gems
bundle package
find . -name *.pid -delete
bundle exec rake db:create && bundle exec rake db:migrate
bundle exec rake setup:admin_role
bundle exec rails hyrax:default_collection_types:create
# It seems like this isn't succeeding for some reason, but doesn't seem to be giving errors
bundle exec rails hyrax:default_admin_set:create
bundle exec sidekiq --daemon
bundle exec rails s -b 0.0.0.0
