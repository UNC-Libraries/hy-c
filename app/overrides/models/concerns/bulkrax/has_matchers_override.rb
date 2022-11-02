# frozen_string_literal: true

# [hyc-override] updating the `multiple?` method to skip attributes without properties
Bulkrax::HasMatchers.module_eval do
  def multiple?(field)
    @multiple_bulkrax_fields ||=
      [
        'file',
        'remote_files',
        "#{related_parents_parsed_mapping}",
        "#{related_children_parsed_mapping}"
      ]

    return true if @multiple_bulkrax_fields.include?(field)
    return false if field == 'model'
    return false if factory_class.properties[field].blank?

    field_supported?(field) && factory_class&.properties&.[](field)&.[]('multiple')
  end
end
