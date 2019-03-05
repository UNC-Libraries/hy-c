config = YAML.load(ERB.new(IO.read(Rails.root + 'config' + 'redis.yml')).result)[Rails.env].with_indifferent_access

redis_conn = { url: "redis://#{config[:host]}:#{config[:port]}/" }

Sidekiq.configure_server do |s|
  s.redis = redis_conn
  Sidekiq::Status.configure_server_middleware s, expiration: 30.days
  Sidekiq::Status.configure_client_middleware s, expiration: 30.days
end

Sidekiq.configure_client do |s|
  s.redis = redis_conn
  Sidekiq::Status.configure_client_middleware s, expiration: 30.days
end