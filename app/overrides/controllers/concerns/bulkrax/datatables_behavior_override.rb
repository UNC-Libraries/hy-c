# frozen_string_literal: true
# https://github.com/samvera/bulkrax/blob/v9.5.1/app/controllers/concerns/bulkrax/datatables_behavior.rb
#  @TODO Fixes upstream bug, where pagination is not working correctly. This is a temporary fix until the bug is fixed upstream.

Bulkrax::DatatablesBehavior.module_eval do
  def format_importers(importers, filtered_count = Bulkrax::Importer.count)
    result = importers.map do |i|
      {
        name: view_context.link_to(i.name, view_context.importer_path(i)),
        status_message: status_message_for(i),
        last_imported_at: i.last_imported_at&.strftime("%b %d, %Y"),
        next_import_at: i.next_import_at&.strftime("%b %d, %Y"),
        enqueued_records: i.last_run&.enqueued_records,
        processed_records: i.last_run&.processed_records || 0,
        failed_records: i.last_run&.failed_records || 0,
        deleted_records: i.last_run&.deleted_records,
        total_collection_entries: i.last_run&.total_collection_entries,
        total_work_entries: i.last_run&.total_work_entries,
        total_file_set_entries: i.last_run&.total_file_set_entries,
        actions: importer_util_links(i)
      }
    end
    {
      data: result,
      recordsTotal:    Bulkrax::Importer.count,
      recordsFiltered: filtered_count
    }
  end

  def format_exporters(exporters, filtered_count = Bulkrax::Exporter.count)
    result = exporters.map do |e|
      {
        name: view_context.link_to(e.name, view_context.exporter_path(e)),
        status_message: status_message_for(e),
        created_at: e.created_at,
        download: download_zip(e),
        actions: exporter_util_links(e)
      }
    end
    {
      data: result,
      recordsTotal: Bulkrax::Exporter.count,
      recordsFiltered: filtered_count
    }
  end
end
