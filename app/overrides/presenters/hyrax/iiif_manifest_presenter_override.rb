# app/presenters/hyrax/iiif_manifest_presenter.rb
# https://github.com/samvera/hyrax/blob/main/app/presenters/hyrax/iiif_manifest_presenter.rb
Hyrax::IiifManifestPresenter.class_eval do
  ##
  # [hyc-override] Overriding iiif manifest metadata to check that field exists on a presenter
  # IIIF metadata for inclusion in the manifest
  #  Called by the `iiif_manifest` gem to add metadata
  #
  # @todo should this use the simple_form i18n keys?! maybe the manifest
  #   needs its own?
  #
  # @return [Array<Hash{String => String}>] array of metadata hashes
  def manifest_metadata
    metadata = []

    metadata_fields.each do |field|
      next unless (respond_to? field) && !send(field).blank?

      field_value = send(field)

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
