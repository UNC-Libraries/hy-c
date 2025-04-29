# frozen_string_literal: true
# [hyc-override] https://github.com/sul-dlss/blacklight_dynamic_sitemap/blob/v1.0.0/app/models/blacklight_dynamic_sitemap/sitemap.rb

BlacklightDynamicSitemap::Sitemap.class_eval do
  def get(id)
    # if someone's hacking URLs (in ways that could potentially generate enormous requests),
    # just return an empty response
    return [] if id.length != exponent

    index_connection.public_send(solr_endpoint,
      params: show_params(id, engine_config.default_params.merge({
        # [hyc-override] only includes open visibility records
        fq: ["{!prefix f=#{hashed_id_field} v=#{id}}", 'visibility_ssi:open'],
        # [hyc-override] Add in has_model for use in generating work page urls
        fl: [unique_id_field, last_modified_field, 'has_model_ssim'].join(','),
        # [hyc-override] Increase number of rows, disabling faceting
        rows: 20_000_000,
        facet: false
      }))
    ).dig('response', 'docs')
  end
end
