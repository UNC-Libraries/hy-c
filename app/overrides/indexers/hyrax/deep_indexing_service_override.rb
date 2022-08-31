# frozen_string_literal: true
# [hyc-override] Overriding to add method to return custom label and save it to Solr
# Note: Customizations are very specific to the Location controlled vocabulary
# https://github.com/samvera/hyrax/blob/v2.9.6/app/indexers/hyrax/deep_indexing_service.rb
Hyrax::DeepIndexingService.class_eval do
  private

  def append_label_and_uri(solr_doc, solr_field_key, field_info, val)
    full_label = parse_geo_request(val.to_uri.to_s)
    val = val.solrize(full_label)
    create_and_insert_terms_handler.create_and_insert_terms(solr_field_key,
                                                            val.first,
                                                            field_info.behaviors, solr_doc)
    return unless val.last.is_a? Hash

    create_and_insert_terms_handler.create_and_insert_terms("#{solr_field_key}_label",
                                                            label(val),
                                                            field_info.behaviors, solr_doc)
  end

  # [hyc-override] Method to return custom label
  def parse_geo_request(location)
    geo_id = location.match(/\d+/)[0]
    request = HTTParty.get("http://api.geonames.org/getJSON?geonameId=#{geo_id}&username=#{ENV['GEONAMES_USER']}")
    response = JSON.parse(request.body)
    # Remove empty elements to avoid trailing commas
    human_readable_location = [response['asciiName'], response['adminName1'], response['countryName']].reject(&:blank?)
    human_readable_location.join(', ')
  rescue StandardError => e
    Rails.logger.warn "Unable to index location for #{location} from geonames service"
    GeonamesMailer.send_mail(e)
    ''
  end


end
