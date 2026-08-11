#!/bin/bash
echo "#### Running start-sidekiq.sh"

echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v 3.5.22
update_rubygems >> /dev/null

bundle config build.nokogiri --use-system-libraries
bundle config set force_ruby_platform true

BUNDLER_VERSION=4.0.12
gem install bundler:"$BUNDLER_VERSION"
bundle _${BUNDLER_VERSION}_ install
ln -sf /usr/local/lib64/gems/ruby/sassc-2.4.0/sassc/libsass.so \
       /usr/local/share/gems/gems/sassc-2.4.0/lib/sassc/libsass.so

echo "#### Starting sidekiq"
bundle exec sidekiq
echo "#### Shutdown sidekiq"