# frozen_string_literal: true
# https://github.com/samvera-labs/bulkrax/blob/v4.4.0/app/factories/bulkrax/object_factory.rb
Bulkrax::ObjectFactory.class_eval do
  private

  # Override if we need to map the attributes from the parser in
  # a way that is compatible with how the factory needs them.
  alias_method :original_transform_attributes, :transform_attributes
  def transform_attributes(update: false)
    original_transform_attributes(update: update)

    # [hyc-override] fix enumeration of fields
    correct_value_types
    # [hyc-override] Move and convert person fields to _attributes field for updating
    prepare_person_fields

    update ? @transform_attributes.except(:id) : @transform_attributes
  end

  # Changes attribute values to multi or single valued to match expected types in the object model
  def correct_value_types
    resource = @klass.new
    @transform_attributes.each do |k, v|
      # check if attribute is single-valued but is currently an array
      @transform_attributes[k] = if resource.attributes.keys.member?(k.to_s) && !resource.attributes[k.to_s].respond_to?(:each) && @transform_attributes[k].respond_to?(:each)
                                   v.first
                                   # check if attribute is multi-valued but is currently not an array
                                 elsif resource.attributes.keys.member?(k.to_s) && resource.attributes[k.to_s].respond_to?(:each) && !@transform_attributes[k].respond_to?(:each)
                                   Array(v)
                                   # otherwise, the attribute does not need to be transformed
                                 else
                                   v
                                 end
    end
  end

  # Transforms person fields into _attributes form and moves the value to
  # the related _attributes field in the transform_attributes hash.
  def prepare_person_fields
    people_attributes = {}
    @transform_attributes.each do |k, v|
      if !v.blank? && PersonHelper.person_field?(k)
        unaccounted_for_ids = existing_person_ids(k)
        @transform_attributes.delete(k)
        unprefixed = {}
        v.each_with_index do |person, index|
          unprefixed_person = unprefix_keys(k, person)
          # Remove blank id fields
          unprefixed_person.delete_if { |k, v| k == 'id' && v.blank? }
          unprefixed[index.to_s] = unprefixed_person
          unaccounted_for_ids.delete(unprefixed_person['id'])
        end
        destroy_unaccounted_for(unprefixed, unaccounted_for_ids)
        people_attributes["#{k}_attributes"] = unprefixed
      end
    end
    @transform_attributes.merge!(people_attributes)
  end

  # List the ids of person objects by the provided field type on the object being updated
  def existing_person_ids(field_name)
    people = @object.send(field_name)
    people.to_a.map { |p| p.id }
  end

  # Add entries to people hash to mark unaccounted for ids as destroyed
  def destroy_unaccounted_for(people_hash, unaccounted_for_ids)
    unaccounted_for_ids.each do |id|
      people_hash[people_hash.size.to_s] = { 'id' => id, '_destroy' => true }
    end
  end

  def unprefix_keys(prefix, original)
    original.map { |pk, pv| [pk.delete_prefix(prefix + '_'), pv] }.to_h
  end

  # Regardless of what the Parser gives us, these are the properties we are prepared to accept.
  # [hyc-override] override to allow '_attributes' properties for people objects
  # [hyc-override] override to add admin_set_id and dcmi_type to the list of permitted parameters
  def permitted_attributes
    properties = klass.properties.keys.map(&:to_sym)
    people = properties.map { |p| PersonHelper.person_field?(p) ? p : nil }.compact
    permitted = properties + people.map { |p| "#{p}_attributes".to_sym } + %i[id edit_users edit_groups read_groups visibility work_members_attributes dcmi_type]
    permitted += %i[admin_set_id] if klass != Collection
  end
end
