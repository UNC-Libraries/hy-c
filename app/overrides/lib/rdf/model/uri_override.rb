# frozen_string_literal: true
# [hyc-override] https://github.com/ruby-rdf/rdf/blob/3.2.11/lib/rdf/model/uri.rb
RDF::URI.class_eval do
  def self.intern(str, *args, **options)
    # [hyc-override] Pulling in fix from https://github.com/ruby-rdf/rdf/compare/develop...feature/URI-frozen-bug
    (cache[(str = str.to_s).to_sym] ||= self.new(str.to_s, *args, **options)).freeze
  end
end