# frozen_string_literal: true
# app/presenters/hyrax/iiif_manifest_presenter.rb
# https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/presenters/hyrax/iiif_manifest_presenter.rb
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

    metadata_fields.each do |field_name|
      next unless (respond_to? field_name) && !send(field_name).blank?

      field_value = send(field_name)

      # Remove everything but name from people object terms
      if field_name.to_s.match(/display$/)
        # Name should always be the second value of the split string
        field_value = field_value.map { |f| f.split('||')[1] }
      end

      metadata << {
        'label' => I18n.t("simple_form.labels.defaults.#{field_name}"),
        'value' => Array(field_value).map { |value| scrub(value.to_s) }
      }
    end
    metadata
  end
end
