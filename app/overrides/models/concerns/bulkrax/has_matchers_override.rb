# frozen_string_literal: true

Bulkrax::HasMatchers.module_eval do
  def multiple?(field)
    return true if field == 'file' || field == 'remote_files' || field == 'collections'
    return false if field == 'model'
    return false if factory_class.properties[field].blank?

    field_supported?(field) && factory_class&.properties&.[](field)&.[]('multiple')
  end
end
