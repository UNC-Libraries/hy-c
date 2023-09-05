# frozen_string_literal: true
# https://github.com/projectblacklight/blacklight/blob/v7.33.1/app/helpers/blacklight/facets_helper_behavior.rb
Blacklight::FacetsHelperBehavior.module_eval do
  ##
  # Get the displayable version of a facet's value
  #
  # @param [Object] field
  # @param [String] item value
  # @return [String]
  def facet_display_value(field, item)
    facet_config = facet_configuration_for_field(field)

    value = if item.respond_to? :label
              item.label
            else
              facet_value_for_facet_item(item)
            end

    # [hyc-override] Overriding to transform date facets from EDTF to human readable strings
    value = Hyc::EdtfConvert.convert_from_edtf(value) if field == 'date_issued_sim' || field == 'date_created_sim'

    if facet_config.helper_method
      send facet_config.helper_method, value
    elsif facet_config.query && facet_config.query[value]
      facet_config.query[value][:label]
    elsif facet_config.date
      localization_options = facet_config.date == true ? {} : facet_config.date

      l(value.to_datetime, localization_options)
    else
      value
    end
  end
end