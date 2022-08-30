# frozen_string_literal: false
# [hyc-override] Overriding renderer from gem to display readable versions of EDTF dates
module Hyrax
  module Renderers
    class DateAttributeRenderer < AttributeRenderer
      private

      def attribute_value_to_html(value)
        Date.try(:edtf, value).try(:humanize) ||
            Date.parse(value).to_formatted_s(:standard).try(:edtf).try(:humanize)
      rescue ArgumentError
        value
      end
    end
  end
end
