# frozen_string_literal: true
# [hyc-override] Overriding helper in order to add doi to citation, see line 40
# [hyc-override] Overriding iiif manifest metadata to check that field exists on a presenter
# and add people objects
# https://github.com/samvera/hyrax/blob/v2.9.6/app/presenters/hyrax/work_show_presenter.rb
Hyrax::WorkShowPresenter.class_eval do
  # delegating just :doi seems to exclude the other fields, so pull all fields in from original file
  delegate :title, :date_created, :date_issued, :description, :doi, :creator, :place_of_publication,
           :creator_display, :contributor, :subject, :publisher, :language, :embargo_release_date,
           :lease_expiration_date, :license, :source, :rights_statement, :thumbnail_id, :representative_id,
           :rendering_ids, :member_of_collection_ids, to: :solr_document

  # [hyc-override] Overriding iiif manifest metadata to check that field exists on a presenter
  # IIIF metadata for inclusion in the manifest
  #  Called by the `iiif_manifest` gem to add metadata
  #
  # @return [Array] array of metadata hashes
  def manifest_metadata
    metadata = []
    Hyrax.config.iiif_metadata_fields.each do |field|
      next unless (respond_to? field)
      field_value = send(field)
      next if field_value.blank?

      # Remove everything but name from people object terms
      if field.to_s.match(/display$/)
        # Name should always be the second value of the split string
        field_value = field_value.map { |f| f.split('||')[1] }
      end

      metadata << {
        'label' => I18n.t("simple_form.labels.defaults.#{field}"),
        'value' => Array.wrap(field_value)
      }
    end
    metadata
  end
end
