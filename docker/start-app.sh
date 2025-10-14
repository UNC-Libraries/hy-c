#!/bin/bash
echo "#### Running start-app.sh"

mkdir -p /opt/hyrax/log/

echo "#### Performing config steps"
# The bundle config and package are needed for the odd way we manage gems in production
bundle config --local cache_path /hyc-gems
bundle config build.nokogiri --use-system-libraries
bundle config build.sassc --use-system-libraries
bundle config set force_ruby_platform true

# Clear any existing bundle cache that might have incompatible binaries
bundle config --local clean --force

echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v 3.4.20
update_rubygems >> /dev/null

if ! bundle check; then
  echo "#### Bundle install required"
  rm -f /hyc-gems/* || true
  bundle install
  bundle package
  echo "#### Creating symlink for libsass otherwise bundle cannot find it"
  [ ! -L /usr/share/gems/gems/sassc-2.4.0/lib/sassc/libsass.so ] && ln -s /usr/lib64/gems/ruby/sassc-2.4.0/sassc/libsass.so /usr/share/gems/gems/sassc-2.4.0/lib/sassc/libsass.so
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

echo "####  Keep the container running for debugging"
# Keep the container running for debugging
while true; do sleep 30; done;