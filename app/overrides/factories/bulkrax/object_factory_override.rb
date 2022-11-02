# frozen_string_literal: true

Bulkrax::ObjectFactory.class_eval do
  private

  # Override if we need to map the attributes from the parser in
  # a way that is compatible with how the factory needs them.
  # override to fix enumeration and formatting of people objects
  def transform_attributes
    attrs = attributes.slice(*permitted_attributes).merge(file_attributes(update_files))
    resource = @klass.new
    attrs.each do |k, v|
      # check if attribute is single-valued but is currently an array
      attrs[k] = if resource.attributes.keys.member?(k.to_s) && !resource.attributes[k.to_s].respond_to?(:each) && attrs[k].respond_to?(:each)
                   v.first
                   # check if attribute is multi-valued but is currently not an array
                 elsif resource.attributes.keys.member?(k.to_s) && resource.attributes[k.to_s].respond_to?(:each) && !attrs[k].respond_to?(:each)
                   Array(v)
                   # otherwise, the attribute does not need to be transformed
                 else
                   v
                 end
    end

    # convert people objects from hash notation to valid json
    attrs.each do |k, v|
      attrs[k] = JSON.parse(v.gsub('=>', ':').gsub("'", '"')) if k.ends_with? '_attributes'
    end

    attrs
  end

  # Regardless of what the Parser gives us, these are the properties we are prepared to accept.
  # override to allow '_attributes' properties for people objects
  # override to add admin_set_id and dcmi_type to the list of permitted parameters
  def permitted_attributes
    people_types = [:advisors, :arrangers, :composers, :contributors, :creators, :project_directors, :researchers,
                    :reviewers, :translators]
    properties = klass.properties.keys.map(&:to_sym)
    people = properties.map { |p| people_types.include?(p) ? p : nil }.compact
    properties + people.map { |p| "#{p}_attributes".to_sym } + %i[id edit_users edit_groups read_groups visibility work_members_attributes admin_set_id dcmi_type]
  end
end
