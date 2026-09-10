# frozen_string_literal: true
# https://github.com/samvera/bulkrax/blob/v9.5.1/app/controllers/bulkrax/importers_controller.rb
# @TODO Fixes upstream bug, where pagination is not working for ImportersController#exporter_table. This is a temporary fix until the bug is fixed upstream.

Bulkrax::ImportersController.class_eval do
  def importer_table
    @importers = Bulkrax::Importer.all
    @importers = @importers.where(importer_table_search) if importer_table_search.present?
    filtered_count = @importers.count
    @importers = Importer.order(importer_table_order).page(table_page).per(table_per_page)
    respond_to do |format|
      format.json { render json: format_importers(@importers, filtered_count) }
    end
  end
end
