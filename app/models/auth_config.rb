class AuthConfig
  # In production, use Shibboleth for user authentication,
  # but in development mode, use local database
  # authentication instead.
  def self.use_database_auth?
    ENV['DATABASE_AUTH'] == 'true'
  end
end
