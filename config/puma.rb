# frozen_string_literal: true
# https://gist.github.com/danielalvarenga/fb89c35a7d7370e033986fa4bdb6d26a

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
# More: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#threads
#
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
# More: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#port
#
port        ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
# More: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#environment
#
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked webserver processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
# More: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#workers
#
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
# More: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#preload-app
#
preload_app!

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

########## Aditional Configurations ##########

# An internal health check to verify that workers have checked in to the master
# process within a specific time frame. If this time is exceeded, the worker
# will automatically be rebooted. Defaults to 60s.
#
# Under most situations you will not have to tweak this value, which is why it
# is coded into the config rather than being an environment variable.
#
worker_timeout ENV.fetch('WORKER_TIMEOUT') { 30 }

# The path to the puma binary without any arguments.
restart_command 'puma'

# If you are preloading your application and using Active Record, it's
# recommended that you close any connections to the database before workers
# are forked to prevent connection leakage.
#
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

# The code in the `on_worker_boot` will be called if you are using
# clustered mode by specifying a number of `workers`. After each worker
# process is booted, this block will be run. If you are using the `preload_app!`
# option, you will want to use this block to reconnect to any threads
# or connections that may have been created at application boot, as Ruby
# cannot share connections between processes.
# More: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
#
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end