# frozen_string_literal: true
# [hyc-override] https://github.com/sul-dlss/blacklight_dynamic_sitemap/blob/v1.0.0/app/views/blacklight_dynamic_sitemap/sitemap/show.xml.builder

xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.urlset(
  'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
  'xsi:schemaLocation' => 'http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd',
  'xmlns' => 'http://www.sitemaps.org/schemas/sitemap/0.9'
) do
  config = BlacklightDynamicSitemap::Engine.config
  @sitemap_entries.each do |doc|
    # [hyc-override] convert doc from Hash to "mock" SolrDocument (from OregonDigital)
    doc = SolrDocument.new doc
    location = doc['has_model_ssim'].first == 'Collection' ? hyrax.collection_url(doc) : main_app.polymorphic_url(doc)
    xml.url do
      # [hyc-override] present correct polymorphic path (from OregonDigital)
      xml.loc(location)
      last_modified = doc[config.last_modified_field]
      xml.lastmod(config.format_last_modified&.call(last_modified) || last_modified)
    end
  end
end
