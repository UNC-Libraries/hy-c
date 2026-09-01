# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/bulkrax/blob/v9.5.1/app/models/concerns/bulkrax/has_matchers.rb

module HycBulkraxHasMatchersOverride
  def multiple?(field)
    # [hyc-override] removed rights_statement from the list since it is not multiple for us
    @multiple_bulkrax_fields ||= %W[
      file
      remote_files
      #{related_parents_parsed_mapping}
      #{related_children_parsed_mapping}
    ]

    return true if @multiple_bulkrax_fields.include?(field)
    return false if field.to_s == 'model'
    # [hyc-override] updating the `multiple?` method to skip attributes without properties
    return false if factory_class&.properties&.[](field).blank?

    field_supported?(field) && factory_class&.properties&.[](field)&.[]('multiple')
  end
end

Bulkrax::HasMatchers.prepend(HycBulkraxHasMatchersOverride)
