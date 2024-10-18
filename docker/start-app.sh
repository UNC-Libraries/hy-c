#!/bin/bash
echo "#### Running start-app.sh"
source scl_source enable rh-ruby30
source scl_source enable devtoolset-8

mkdir -p /opt/hyrax/log/
echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v 3.4.20
update_rubygems >> /dev/null

echo "#### Performing config steps"
# The bundle config and package are needed for the odd way we manage gems in production
bundle config --local cache_path /hyc-gems

if ! bundle check; then
  echo "#### Bundle install required"
  bundle install
  bundle package
  echo "#### Creating symlink for libsass otherwise bundle cannot find it"
  [ ! -L /opt/rh/rh-ruby30/root/usr/share/gems/gems/sassc-2.4.0/ext/libsass.so ] && ln -s /opt/rh/rh-ruby30/root/usr/lib64/gems/ruby/sassc-2.4.0/sassc/libsass.so /opt/rh/rh-ruby30/root/usr/share/gems/gems/sassc-2.4.0/ext/libsass.so
else
  echo "#### Gems already installed, skipping bundle install"
fi

find . -name *.pid -delete
bundle exec rake tmp:cache:clear
bundle exec rake db:create && bundle exec rake db:migrate
bundle exec rake setup:admin_role
bundle exec rails hyrax:default_collection_types:create
bundle exec rails hyrax:default_admin_set:create
echo "#### Starting web application"
bundle exec puma -C config/puma.rb
echo "#### Shutdown web application"