# frozen_string_literal: true

# [hyc-override] Comment out Hyrax::DashboardController.sidebar_partials line, line 74. It breaks hyrax 2.x

Bulkrax.setup do |config|
  # Add local parsers
  # config.parsers += [
  #   { name: 'MODS - My Local MODS parser', class_name: 'Bulkrax::ModsXmlParser', partial: 'mods_fields' },
  # ]

  # WorkType to use as the default if none is specified in the import
  # Default is the first returned by Hyrax.config.curation_concerns
  # config.default_work_type = MyWork

  # Path to store pending imports
  config.import_path = "#{ENV['TEMP_STORAGE']}/hyrax/imports"

  # Path to store exports before download
  config.export_path = "#{ENV['TEMP_STORAGE']}/hyrax/exports"

  # Server name for oai request header
  # config.server_name = 'my_server@name.com'

  # NOTE: Creating Collections using the collection_field_mapping will no longer be supported as of Bulkrax version 3.0.
  #       Please configure Bulkrax to use related_parents_field_mapping and related_children_field_mapping instead.
  # Field_mapping for establishing a collection relationship (FROM work TO collection)
  # This value IS NOT used for OAI, so setting the OAI parser here will have no effect
  # The mapping is supplied per Entry, provide the full class name as a string, eg. 'Bulkrax::CsvEntry'
  # The default value for CSV is collection
  # Add/replace parsers, for example:
  # config.collection_field_mapping['Bulkrax::RdfEntry'] = 'http://opaquenamespace.org/ns/set'

  # Field mappings
  # Create a completely new set of mappings by replacing the whole set as follows
  #   config.field_mappings = {
  #     "Bulkrax::OaiDcParser" => { **individual field mappings go here*** }
  #   }
  config.field_mappings = {
    'Bulkrax::CsvParser' => {
      'id' => { from: ['id'] },
      'model' => { from: ['model'] },
      'abstract' => { from: ['abstract'] },
      'academic_concentration' => { from: ['academic_concentration'] },
      'access' => { from: ['access'] },
      'admin_note' => { from: ['admin_note'] },
      'alternative_title' => { from: ['alternative_title'] },
      'award' => { from: ['award'] },
      'based_near' => { from: ['based_near'] },
      'bibliographic_citation' => { from: ['bibliographic_citation'] },
      'conference_name' => { from: ['conference_name'] },
      'copyright_date' => { from: ['copyright_date'] },
      'date_captured' => { from: ['date_captured'] },
      'date_created' => { from: ['date_created'] },
      'date_issued' => { from: ['date_issued'] },
      'date_other' => { from: ['date_other'] },
      'dcmi_type' => { from: ['dcmi_type'] },
      'degree' => { from: ['degree'] },
      'degree_granting_institution' => { from: ['degree_granting_institution'] },
      'deposit_agreement' => { from: ['deposit_agreement'] },
      'deposit_record' => { from: ['deposit_record'] },
      'description' => { from: ['description'] },
      'digital_collection' => { from: ['digital_collection'] },
      'doi' => { from: ['doi'] },
      'edition' => { from: ['edition'] },
      'extent' => { from: ['extent'] },
      'funder' => { from: ['funder'] },
      'graduation_year' => { from: ['graduation_year'] },
      'identifier' => { from: ['identifier'], split: true },
      'isbn' => { from: ['isbn'] },
      'issn' => { from: ['issn'], split: true },
      'journal_issue' => { from: ['journal_issue'] },
      'journal_title' => { from: ['journal_title'] },
      'journal_volume' => { from: ['journal_volume'] },
      'keyword' => { from: ['keyword'], split: true },
      'kind_of_data' => { from: ['kind_of_data'] },
      'language' => { from: ['language'], split: true },
      'language_label' => { from: ['language_label'], split: true },
      'last_modified_date' => { from: ['last_modified_date'] },
      'license' => { from: ['license'] },
      'license_label' => { from: ['license_label'] },
      'medium' => { from: ['medium'] },
      'methodology' => { from: ['methodology'] },
      'note' => { from: ['note'] },
      'page_end' => { from: ['page_end'] },
      'page_start' => { from: ['page_start'] },
      "parent" => { from: ["parent"], related_parents_field_mapping: true },
      "parent_title" => { from: ["parent_title"] },
      'peer_review_status' => { from: ['peer_review_status'] },
      'place_of_publication' => { from: ['place_of_publication'] },
      'publisher' => { from: ['publisher'] },
      'related_url' => { from: ['related_url'] },
      'resource_type' => { from: ['resource_type'] },
      'rights_holder' => { from: ['rights_holder'] },
      'rights_statement' => { from: ['rights_statement'] },
      'rights_statement_label' => { from: ['rights_statement_label'] },
      'series' => { from: ['series'] },
      'source_identifier' => { from: ['source_identifier'] },
      'sponsor' => { from: ['sponsor'] },
      'subject' => { from: ['subject'] },
      'table_of_contents' => { from: ['table_of_contents'] },
      'title' => { from: ['title'], parsed: true },
      'url' => { from: ['url'] },
      'use' => { from: ['use'] },
      'file' => { from: ['file'] },
      'advisors_attributes' => { from: ['advisors_attributes'] },
      'arrangers_attributes' => { from: ['arrangers_attributes'] },
      'composers_attributes' => { from: ['composers_attributes'] },
      'contributors_attributes' => { from: ['contributors_attributes'] },
      'creators_attributes' => { from: ['creators_attributes'] },
      'project_directors_attributes' => { from: ['project_directors_attributes'] },
      'researchers_attributes' => { from: ['researchers_attributes'] },
      'reviewers_attributes' => { from: ['reviewers_attributes'] },
      'translators_attributes' => { from: ['translators_attributes'] }
    }
  }

  # Add to, or change existing mappings as follows
  #   e.g. to exclude date
  #   config.field_mappings["Bulkrax::OaiDcParser"]["date"] = { from: ["date"], excluded: true  }
  #
  #   e.g. to import parent-child relationships
  #   config.field_mappings['Bulkrax::CsvParser']['parents'] = { from: ['parents'], related_parents_field_mapping: true }
  #   config.field_mappings['Bulkrax::CsvParser']['children'] = { from: ['children'], related_children_field_mapping: true }
  #   (For more info on importing relationships, see Bulkrax Wiki: https://github.com/samvera-labs/bulkrax/wiki/Configuring-Bulkrax#parent-child-relationship-field-mappings)
  #
  # #   e.g. to add the required source_identifier field
  #   #   config.field_mappings["Bulkrax::CsvParser"]["source_id"] = { from: ["old_source_id"], source_identifier: true  }
  # If you want Bulkrax to fill in source_identifiers for you, see below

  # To duplicate a set of mappings from one parser to another
  #   config.field_mappings["Bulkrax::OaiOmekaParser"] = {}
  #   config.field_mappings["Bulkrax::OaiDcParser"].each {|key,value| config.field_mappings["Bulkrax::OaiOmekaParser"][key] = value }

  # Should Bulkrax make up source identifiers for you? This allow round tripping
  # and download errored entries to still work, but does mean if you upload the
  # same source record in two different files you WILL get duplicates.
  # It is given two aruguments, self at the time of call and the index of the reocrd
  #    config.fill_in_blank_source_identifiers = ->(parser, index) { "b-#{parser.importer.id}-#{index}"}
  # or use a uuid
  config.fill_in_blank_source_identifiers = ->(parser, index) { SecureRandom.uuid }

  # Properties that should not be used in imports/exports. They are reserved for use by Hyrax.
  # config.reserved_properties += ['my_field']
end

# Sidebar for hyrax 3+ support
Hyrax::DashboardController.sidebar_partials[:repository_content] << 'hyrax/dashboard/sidebar/bulkrax_sidebar_additions' if Object.const_defined?(:Hyrax) && ::Hyrax::DashboardController&.respond_to?(:sidebar_partials)
