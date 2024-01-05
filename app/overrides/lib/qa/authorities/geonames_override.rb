# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/questioning_authority/blob/v5.10.0/lib/qa/authorities/geonames.rb
Qa::Authorities::Geonames.class_eval do
  # [hyc-override] Bumping up the max results returned, as geonames doesn't deal well with multi-word states
  def build_query_url(q)
    query = ERB::Util.url_encode(untaint(q))
    File.join(query_url_host, "searchJSON?q=#{query}&username=#{username}&maxRows=25")
  end

  # [hyc-override] Modification to remove whitespace and only display the name field if the location is a country (fcode == PCLI or PCLS)
  # https://www.geonames.org/export/codes.html
  self.label = lambda do |item|
    if item['fcode'] == 'PCLI' || item['fcode'] == 'PCLS'
      values = [item['name']]
    else
      # Exclude nil, empty string, and whitespace-only values
      values = [item['name'], item['adminName1'], item['countryName']].reject { |v| v.nil? || v.strip.empty? }
    end
    values.join(', ')
  end
end
