#!/bin/bash
echo "#### Running start-sidekiq.sh"

echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v 3.4.20
update_rubygems >> /dev/null

bundle config --local cache_path /hyc-gems
bundle config build.nokogiri --use-system-libraries
bundle config build.sassc --use-system-libraries
bundle config set force_ruby_platform true

if ! bundle check; then
  echo "#### Bundle install required"
  bundle install
  bundle package
  echo "#### Creating symlink for libsass otherwise bundle cannot find it"
  [ ! -L /usr/share/gems/gems/sassc-2.4.0/lib/sassc/libsass.so ] && ln -s /usr/lib64/gems/ruby/sassc-2.4.0/sassc/libsass.so /usr/share/gems/gems/sassc-2.4.0/lib/sassc/libsass.so
else
  echo "#### Gems already installed, skipping bundle install"
fi

echo "#### Starting sidekiq"
bundle exec sidekiq
echo "#### Shutdown sidekiq"