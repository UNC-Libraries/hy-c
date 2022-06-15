# https://gist.github.com/andrius/7c26a8deef10f3105a136f958b0d582d
workers Integer(ENV['WEB_CONCURRENCY'] || [1, `grep -c processor /proc/cpuinfo`.to_i].max - 1)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup DefaultRackup
bind "tcp://0.0.0.0:#{ENV['PORT'] || 3000}"
environment ENV['RACK_ENV'] || 'development'

stdout_redirect(stdout = '/dev/stdout', stderr = '/dev/stderr', append = true)

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # See: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
  ActiveRecord::Base.establish_connection
end
