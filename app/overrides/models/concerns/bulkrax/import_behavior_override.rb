# frozen_string_literal: true
# https://github.com/samvera/bulkrax/blob/v9.5.1/app/models/concerns/bulkrax/import_behavior.rb

module HycBulkraxImportBehaviorOverride
  # [hyc-override] set rights_statement as a single value rather than an array to match our model
  def add_rights_statement
    return unless override_rights_statement || parsed_metadata['rights_statement'].blank?

    self.parsed_metadata['rights_statement'] = parser.parser_fields['rights_statement'].presence
  end
end
Bulkrax::ImportBehavior.prepend(HycBulkraxImportBehaviorOverride)
