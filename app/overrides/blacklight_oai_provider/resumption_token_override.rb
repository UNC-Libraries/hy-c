# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight_oai_provider/blob/v7.0.2/lib/blacklight_oai_provider/resumption_token.rb
module BlacklightOaiProvider
  module ResumptionTokenOverride
    def encode_conditions
      encoded_token = @prefix.to_s.dup
      encoded_token << ".s(#{set})" if set
      # [hyc-override] only call utc if it is supported, which is not the case for Date objects
      encoded_token << ".f(#{date_field_value(from)})" if from
      encoded_token << ".u(#{date_field_value(self.until)})" if self.until
      encoded_token << ".t(#{total})" if total
      encoded_token << ":#{last}"
    end

    def date_field_value(date_field)
      return date_field.utc.xmlschema if date_field.respond_to?(:utc)

      date_field.xmlschema
    end
  end
end

BlacklightOaiProvider::ResumptionToken.prepend(BlacklightOaiProvider::ResumptionTokenOverride)
