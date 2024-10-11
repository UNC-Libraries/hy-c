#!/bin/bash
echo "#### Running start-sidekiq.sh"
source scl_source enable rh-ruby30
source scl_source enable devtoolset-8

echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v 3.4.20
update_rubygems >> /dev/null

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

echo "#### Starting sidekiq"
bundle exec sidekiq
echo "#### Shutdown sidekiq"