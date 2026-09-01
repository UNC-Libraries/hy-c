# frozen_string_literal: true
# https://github.com/samvera-labs/bulkrax/blob/v9.5.1/app/factories/bulkrax/object_factory.rb

module HycBulkraxObjectFactoryOverride
  private

  # Override if we need to map the attributes from the parser in
  # a way that is compatible with how the factory needs them.
  def transform_attributes(update: false)
    super

    # [hyc-override] fix enumeration of fields
    correct_value_types

    # [hyc-override] Move and convert person fields to _attributes field for updating
    prepare_person_fields

    update ? @transform_attributes.except(:id) : @transform_attributes
  end

  # Changes attribute values to multi or single valued to match expected types
  # in the object model
  def correct_value_types
    resource = @klass.new

    @transform_attributes.each do |key, value|
      next unless resource.attributes.keys.member?(key.to_s)

      # check if attribute is single-valued but is currently an array
      @transform_attributes[key] =
        if !resource.attributes[key.to_s].respond_to?(:each) &&
           value.respond_to?(:each)
          value.first

          # check if attribute is multi-valued but is currently not an array
        elsif resource.attributes[key.to_s].respond_to?(:each) &&
              !value.respond_to?(:each)
          Array(value)

          # otherwise, the attribute does not need to be transformed
        else
          value
        end
    end
  end

  # Transforms person fields into _attributes form and moves the value to
  # the related _attributes field in the transform_attributes hash.
  def prepare_person_fields
    people_attributes = {}

    @transform_attributes.each do |key, value|
      next if value.blank?
      next unless PersonHelper.person_field?(key)

      unaccounted_for_ids = existing_person_ids(key)

      @transform_attributes.delete(key)

      unprefixed = {}

      Array(value).each_with_index do |person, index|
        unprefixed_person = unprefix_keys(key, person)

        # Remove blank id fields
        unprefixed_person.delete_if { |person_key, person_value|
          person_key == 'id' && person_value.blank?
        }

        unprefixed[index.to_s] = unprefixed_person
        unaccounted_for_ids.delete(unprefixed_person['id'])
      end

      destroy_unaccounted_for(unprefixed, unaccounted_for_ids)
      people_attributes["#{key}_attributes"] = unprefixed
    end

    @transform_attributes.merge!(people_attributes)
  end

  # List the ids of person objects by the provided field type on the object
  # being updated
  def existing_person_ids(field_name)
    return [] if @object.nil?

    people = @object.public_send(field_name)
    people.to_a.map(&:id)
  end

  # Add entries to people hash to mark unaccounted for ids as destroyed
  def destroy_unaccounted_for(people_hash, unaccounted_for_ids)
    unaccounted_for_ids.each do |id|
      people_hash[people_hash.size.to_s] = { 'id' => id, '_destroy' => true }
    end
  end

  def unprefix_keys(prefix, original)
    original.map do |person_key, person_value|
      [person_key.delete_prefix("#{prefix}_"), person_value]
    end.to_h
  end

  # Regardless of what the Parser gives us, these are the properties we are
  # prepared to accept.
  #
  # [hyc-override] override to allow '_attributes' properties for people objects
  # [hyc-override] override to add admin_set_id and dcmi_type to the list of
  # permitted parameters
  def permitted_attributes
    properties = klass.properties.keys.map(&:to_sym)
    people = properties.select { |property| PersonHelper.person_field?(property) }

    permitted =
      properties +
      people.map { |person| "#{person}_attributes".to_sym } +
      %i[
        id
        edit_users
        edit_groups
        read_groups
        visibility
        work_members_attributes
        dcmi_type
      ]

    permitted += %i[admin_set_id] if klass != Collection

    permitted
  end
end

Bulkrax::ObjectFactory.prepend(HycBulkraxObjectFactoryOverride)
