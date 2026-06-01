#!/bin/bash
echo "#### Running start-app.sh"

mkdir -p /opt/hyrax/log/

echo "#### Performing config steps"
bundle config build.nokogiri --use-system-libraries
bundle config set force_ruby_platform true

echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v 3.4.20
update_rubygems >> /dev/null

echo "#### Bundle install"
bundle install
# sassc's native.rb looks for libsass.so inside its own gem directory, but
# rubygems places compiled extensions under lib64/gems/ruby/. Symlink so sassc
# can find its library at the path it expects.
ln -sf /usr/local/lib64/gems/ruby/sassc-2.4.0/sassc/libsass.so \
       /usr/local/share/gems/gems/sassc-2.4.0/lib/sassc/libsass.so

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