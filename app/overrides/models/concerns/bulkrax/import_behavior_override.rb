# frozen_string_literal: true
# https://github.com/samvera-labs/bulkrax/blob/v4.4.0/app/models/concerns/bulkrax/import_behavior.rb
Bulkrax::ImportBehavior.module_eval do
  # [hyc-override] set rights_statement as a single value rather an an array to match our model
  def add_rights_statement
    self.parsed_metadata['rights_statement'] = parser.parser_fields['rights_statement'] if override_rights_statement || self.parsed_metadata['rights_statement'].blank?
  end
end
