Hyrax::Analytics::Matomo.module_eval do
  class_methods do
    def api_params(method, period, date, additional_params = {})
      params = {
        module: "API",
        idSite: config.site_id,
        method: method,
        period: period,
        date: date,
        format: "JSON",
        token_auth: config.auth_token
      }
      params.merge!(additional_params)
      get(params)
      Rails.logger.error("Matomo API call #{params}")
    end
  end
end
