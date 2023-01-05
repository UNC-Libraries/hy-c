# frozen_string_literal: true
# [hyc-override] check model name before building entry
# https://github.com/samvera-labs/bulkrax/blob/v4.4.0/app/models/bulkrax/csv_entry.rb
Bulkrax::CsvEntry.class_eval do
  WORK_TYPES ||= %w[Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork FileSet Collection]

  alias_method :original_build_metadata, :build_metadata
  def build_metadata
    raise StandardError.new "uninitialized constant #{record['model']} (NameError)" if invalid_model_type(record)
    original_build_metadata
  end

  def invalid_model_type(record)
    return false if record.nil?
    record['model'].nil? || !WORK_TYPES.include?(record['model'])
  end

  def build_object(value)
    data = hyrax_record.send(value['object'])
    return if data.empty?

    data = data.to_a if data.is_a?(ActiveTriples::Relation)
    data = serialize_people(data) if data && data.first.is_a?(Person)
    object_metadata(Array.wrap(data), value['object'])
  end

  # Transform Person objects to hashes, and flatten values from relations to single values
  def serialize_people(data)
    data.map do |d|
      person_hash = d.attributes
      person_hash.each { |k, v| person_hash[k] = v.is_a?(ActiveTriples::Relation) ? v.first : v }
      person_hash.to_s
    end
  end

  def object_metadata(data, object_name)
    data = data.map { |d| eval(d) }.flatten # rubocop:disable Security/Eval

    data.each_with_index do |obj, index|
      next if obj.nil?
      # allow the object_key to be valid whether it's a string or symbol
      obj = obj.with_indifferent_access

      obj.each_key do |key|
        if obj[key].is_a?(Array)
          obj[key].each_with_index do |_nested_item, nested_index|
            self.parsed_metadata["#{key_for_export(key, object_name)}_#{index + 1}_#{nested_index + 1}"] = prepare_export_data(obj[key][nested_index])
          end
        else
          self.parsed_metadata["#{key_for_export(key, object_name)}_#{index + 1}"] = prepare_export_data(obj[key])
        end
      end
    end
  end

  def key_for_export(key, object_name = nil)
    clean_key = key_without_numbers(key)
    if object_name
      # Gather all the mappings related to the provided object field
      object_mappings = mapping.filter { |key, value| value['object'] == object_name }
      # Check if the unprefixed property exists within the properties for object
      unnumbered_key = object_mappings[clean_key]
      # Check if property exists with key prefixed with the object name
      unnumbered_key = object_mappings["#{object_name}_#{clean_key}"] if unnumbered_key.nil?
    else
      unnumbered_key = mapping[clean_key]
    end
    # Use the 'from' name if we found a mapping, otherwise default to key as it appears in the object
    unnumbered_key = unnumbered_key ? unnumbered_key['from'].first : clean_key

    # Bring the number back if there is one
    "#{unnumbered_key}#{key.sub(clean_key, '')}"
  end
end
