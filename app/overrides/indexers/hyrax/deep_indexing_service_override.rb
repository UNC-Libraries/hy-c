# [hyc-override] Overriding to add method to return custom label and save it to Solr
# Note: Customizations are very specific to the Location controlled vocabulary
Hyrax::DeepIndexingService.class_eval do
  private

  # Appends the uri to the default solr field and puts the label (if found) in the label solr field
  # @param [Hash] solr_doc
  # @param [String] solr_field_key
  # @param [Hash] field_info
  # @param [Array] val an array of two elements, first is a string (the uri) and the second is a hash with one key: `:label`
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
    unless Rails.env.test?
      Rails.logger.warn "Unable to index location for #{location} from geonames service"
      mail(to: ENV['EMAIL_GEONAMES_ERRORS_ADDRESS'], subject: 'Unable to index geonames uri to human readable text') do |format|
        format.text { render plain: e.message }
      end
    end
    ''
  end
end
