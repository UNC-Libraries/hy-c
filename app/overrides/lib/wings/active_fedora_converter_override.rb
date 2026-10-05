# frozen_string_literal: true

# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v5.3.0/lib/wings/active_fedora_converter.rb
module HycActiveFedoraConverterOverride
  private

  def parse_attributes(af_object)
    converted_attrs = normal_attributes
    af_object.attributes = converted_attrs.except(:members, :files, :file_name)
    af_object.original_filename = converted_attrs[:file_name] if converted_attrs[:file_name]
    # [hyc-override] Reassigning extracted_text deletes the existing directly
    # contained file before Wings can add it back. Visibility propagation does not
    # modify extracted text, so leave the existing association unchanged.
    # af_object.extracted_text = create_extrated_text(af_object) if resource.attributes[:extracted_text_id].present?
    perform_lease_conversion(af_object: af_object, resource: resource)
    perform_embargo_conversion(af_object: af_object, resource: resource)

    if converted_attrs.keys.include?(:members)
      members = Array.wrap(converted_attrs.delete(:members))
      members.empty? ? af_object.try(:ordered_members)&.clear : af_object.try(:ordered_members=, members)
      af_object.try(:members)&.replace(members)
    end

    return unless converted_attrs.keys.include?(:files)

    files = converted_attrs.delete(:files)
    af_object.files.build_or_set(files) if files
  end
end

Wings::ActiveFedoraConverter.prepend(HycActiveFedoraConverterOverride) unless
  Wings::ActiveFedoraConverter.ancestors.include?(HycActiveFedoraConverterOverride)
