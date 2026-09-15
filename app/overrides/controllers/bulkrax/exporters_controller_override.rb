# frozen_string_literal: true
# https://github.com/samvera/bulkrax/blob/v9.5.1/app/controllers/bulkrax/exporters_controller.rb
# @TODO Fixes upstream bug, where pagination is not working for ExportersController#exporter_table. This is a temporary fix until the bug is fixed upstream.

Bulkrax::ExportersController.class_eval do
  def exporter_table
    @exporters = Bulkrax::Exporter.all
    @exporters = @exporters.where(exporter_table_search) if exporter_table_search.present?
    filtered_count = @exporters.count
    @exporters = @exporters.reorder(table_order).page(table_page).per(table_per_page)
    respond_to do |format|
      format.json { render json: format_exporters(@exporters, filtered_count) }
    end
  end
end
