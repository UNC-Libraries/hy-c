# frozen_string_literal: true
class DecodeQueryString
  def initialize(app)
    @app = app
  end

  def call(env)
    if env['QUERY_STRING']
      # Decode the '%3D' character
      query_string = env['QUERY_STRING'].gsub('%5D%3D', '%5D=')
      env['QUERY_STRING'] = query_string
    end
    @app.call(env)
  end
end
