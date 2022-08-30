Hyrax::Renderers::DateAttributeRenderer.class_eval do
  private

  def attribute_value_to_html(value)
    Date.try(:edtf, value).try(:humanize) ||
      Date.parse(value).to_formatted_s(:standard).try(:edtf).try(:humanize)
  rescue ArgumentError
    value
  end
end
