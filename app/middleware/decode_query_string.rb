# frozen_string_literal: true
class DecodeQueryString
  def initialize(app)
    @app = app
  end

  def call(env)
    if env['QUERY_STRING']
      # Decode the '%3D' character
      query_string = URI.decode_www_form_component(env['QUERY_STRING']).gsub('%3D', '=')
      env['QUERY_STRING'] = query_string
    end
    @app.call(env)
  end
end
