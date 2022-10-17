# [hyc-override] Overriding hydra editor custom input to allow for multivalue HTML5 dates and integers
# [hyc-override] Overriding hydra editor custom input to allow for accessibility validation
# https://github.com/samvera/hydra-editor/blob/main/app/inputs/multi_value_input.rb
MultiValueInput.class_eval do
  def build_field_options(value, index)
    options = input_html_options.dup

    should_format = options[:type] != 'textarea' && !options[:class].include?('date-input') &&
      !options[:class].include?('integer-input')
    options[:value] = format_value(value, should_format)
    if @rendered_first_element
      options[:id] = nil
      options[:required] = nil
    else
      options[:id] ||= input_dom_id
    end
    options[:class] ||= []
    options[:class] += ["#{input_dom_id} form-control multi-text-field"]
    options[:'aria-labelledby'] = label_id
    @rendered_first_element = true

    options
  end

  def build_field(value, index)
    options = build_field_options(value, index)
    if options.delete(:type) == 'textarea'.freeze
      @builder.text_area(attribute_name, options)
    elsif options[:class].include? 'integer-input' #[hyc-override] multivalue integers
      @builder.number_field(attribute_name, options)
    elsif options[:class].include? 'date-input' #[hyc-override] multivalue dates
      @builder.date_field(attribute_name, options)
    else
      @builder.text_field(attribute_name, options)
    end
  end

  # [hyc-override] Overriding hydra editor custom input to allow for correct label to input linking
  def label_id
    input_dom_id
  end

  #[hyc-override] convert from EDTF for multivalue dates
  def format_value(value, should_format)
    return Hyc::EdtfConvert.convert_from_edtf(value) if should_format && value.to_s.strip =~ /^(\d{4}|\d{3}(u|x)|\d{2}xx|[u]{4})/

    value
  end
end