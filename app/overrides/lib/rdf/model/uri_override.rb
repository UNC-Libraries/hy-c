# frozen_string_literal: true
# [hyc-override] https://github.com/ruby-rdf/rdf/blob/3.2.11/lib/rdf/model/uri.rb
RDF::URI.class_eval do
  # [hyc-override] Wrap the entire method in mutex, rather than just the interior of the unless block
  def freeze
    @mutex.synchronize do
      unless frozen?
        # Create derived components
        authority; userinfo; user; password; host; port
        @value  = value.freeze
        @object = object.freeze
        @hash = hash.freeze
        super
      end
    end
    self
  end
end
