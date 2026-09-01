# frozen_string_literal: true
# https://github.com/samvera/bulkrax/blob/v9.5.1/app/models/bulkrax/csv_entry.rb

module HycBulkraxCsvEntryOverride
  UPDATABLE_TYPES = %w[
    Article
    Artwork
    DataSet
    Dissertation
    General
    HonorsThesis
    Journal
    MastersPaper
    Multimed
    ScholarlyWork
    FileSet
    Collection
  ].freeze

  # [hyc-override] check model name before building entry
  def build_metadata
    raise StandardError, "uninitialized constant #{record['model']} (NameError)" if invalid_model_type(record)

    super
  end

  def invalid_model_type(record)
    return false if record.nil?

    record['model'].nil? || !UPDATABLE_TYPES.include?(record['model'])
  end

  def build_object(_key, value)
    return unless hyrax_record.respond_to?(value['object'])

    data = hyrax_record.public_send(value['object'])
    return if data.empty?

    data = data.to_a if data.is_a?(ActiveTriples::Relation)

    # [hyc-override] convert people objects to the hash serialization expected by bulkrax
    data = serialize_people(data, value['object']) if data.first.is_a?(Person)

    object_metadata(Array.wrap(data))
  end

  # [hyc-override] Transform Person objects to hashes, flatten values from
  # relations to single values, and prefix keys with the object name.
  def serialize_people(data, object_name)
    data.map do |person|
      person_hash = person.attributes

      person_hash.each do |key, value|
        person_hash[key] =
          value.is_a?(ActiveTriples::Relation) ? value.first : value
      end

      prefixed_hash = person_hash.to_h.transform_keys do |key|
        key = key.to_s
        key.start_with?("#{object_name}_") ? key : "#{object_name}_#{key}"
      end

      prefixed_hash.to_s
    end
  end
end

Bulkrax::CsvEntry.prepend(HycBulkraxCsvEntryOverride)
