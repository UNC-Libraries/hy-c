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
        @transform_attributes.delete(k)
        unprefixed = {}
        v.each_with_index do |person, index|
          unprefixed[index.to_s] = unprefix_keys(k, person)
        end
        people_attributes["#{k}_attributes"] = unprefixed
      end
    end
    @transform_attributes.merge!(people_attributes)
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
    properties + people.map { |p| "#{p}_attributes".to_sym } + %i[id edit_users edit_groups read_groups visibility work_members_attributes admin_set_id dcmi_type]
  end
end
