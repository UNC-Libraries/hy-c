#!/bin/bash
echo "#### Running start-app.sh"
source scl_source enable rh-ruby27
source scl_source enable devtoolset-8

mkdir -p /opt/hyrax/log/
echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v '~> 3.4'
update_rubygems  >> /dev/null

echo "#### Bundle install"
bundle check || bundle install

echo "#### Performing config steps"
# The bundle config and package are needed for the odd way we manage gems in production
bundle config --local cache_path /hyc-gems
bundle package
find . -name *.pid -delete
bundle exec rake tmp:cache:clear
bundle exec rake db:create && bundle exec rake db:migrate
bundle exec rake setup:admin_role
bundle exec rails hyrax:default_collection_types:create
bundle exec rails hyrax:default_admin_set:create
echo "#### Starting web application"
bundle exec puma -C config/puma.rb
echo "#### Shutdown web application"
