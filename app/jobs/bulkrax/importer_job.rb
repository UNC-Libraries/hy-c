# frozen_string_literal: true
# [hyc-override] set only_updates before validating uploaded file

module Bulkrax
  class ImporterJob < ApplicationJob
    queue_as :import

    def perform(importer_id, only_updates_since_last_import = false)
      importer = Importer.find(importer_id)

      import(importer, only_updates_since_last_import)
      schedule(importer) if importer.schedulable?
    end

    # set only_updates before validating
    def import(importer, only_updates_since_last_import)
      importer.only_updates = only_updates_since_last_import || false
      return unless importer.valid_import?
      importer.import_collections
      importer.import_works(only_updates_since_last_import)
      importer.create_parent_child_relationships unless importer.validate_only
    end

    def schedule(importer)
      ImporterJob.set(wait_until: importer.next_import_at).perform_later(importer.id, true)
    end
  end
end