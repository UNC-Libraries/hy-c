# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/questioning_authority/blob/v5.10.0/lib/qa/authorities/geonames.rb
Qa::Authorities::Geonames.class_eval do
  # [hyc-override] Bumping up the max results returned, as geonames doesn't deal well with multi-word states
  def build_query_url(q)
    query = ERB::Util.url_encode(untaint(q))
    File.join(query_url_host, "searchJSON?q=#{query}&username=#{username}&maxRows=25")
  end
end
