# [hyc-override] making local changes to teample from bulkrax gem
# frozen_string_literal: true

module Bulkrax::HasLocalProcessing
  # This method is called during build_metadata
  # add any special processing here, for example to reset a metadata property
  # to add a custom property from outside of the import data
  def add_local
    # add rights statement label
    if self.parsed_metadata.key?('rights_statement') && !self.parsed_metadata['rights_statement'].blank? &&
        !self.parsed_metadata.key?('rights_statement_label')
      self.parsed_metadata['rights_statement_label'] = CdrRightsStatementsService.label(self.parsed_metadata['rights_statement'].first)
    end

    # add language label
    if self.parsed_metadata.key?('language') && !self.parsed_metadata['language'].blank? &&
        !self.parsed_metadata.key?('language_label')
      self.parsed_metadata['language_label'] = LanguagesService.label(self.parsed_metadata['language'].first)
    end

    # add license label
    if self.parsed_metadata.key?('license') && !self.parsed_metadata['license'].blank? &&
        !self.parsed_metadata.key?('license_label')
      self.parsed_metadata['license_label'] = CdrLicenseService.label(self.parsed_metadata['license'].first)
    end

    # use admin set chosen in form if not already set
    self.parsed_metadata['admin_set_id'] ||= importerexporter.admin_set_id
  end
end
