#!/bin/bash
echo "#### Running start-sidekiq.sh"
source scl_source enable rh-ruby27
source scl_source enable devtoolset-8

# Wait for the web container, so that it can handle installation of bundle gems for both
echo "#### Waiting for web application to become available"
ATTEMPT_COUNTER=0
MAX_ATTEMPTS=100
SERVICE_URL=http://web:3000/

until $(curl --output /dev/null --silent --head --fail $SERVICE_URL); do
    if [ ${ATTEMPT_COUNTER} -eq ${MAX_ATTEMPTS} ];then
      echo "Max attempts to connect to web application reached, cannot start sidekiq"
      exit 1
    fi

    printf '.'
    ATTEMPT_COUNTER=$(($ATTEMPT_COUNTER+1))
    sleep 5
done

echo "#### Ensure rubygems system is up to date before bundle installing"
gem install rubygems-update -v '~> 3.4'
update_rubygems >> /dev/null

echo "#### Starting sidekiq"
bundle && bundle exec sidekiq
echo "#### Shutdown sidekiq"