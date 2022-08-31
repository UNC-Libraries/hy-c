# [hyc-override] Overriding renderer from gem to display readable versions of EDTF dates
# https://github.com/samvera/hyrax/blob/v2.9.6/app/renderers/hyrax/renderers/date_attribute_renderer.rb
Hyrax::Renderers::DateAttributeRenderer.class_eval do
  private

  def attribute_value_to_html(value)
    Date.try(:edtf, value).try(:humanize) ||
      Date.parse(value).to_formatted_s(:standard).try(:edtf).try(:humanize)
  rescue ArgumentError
    value
  end
end
