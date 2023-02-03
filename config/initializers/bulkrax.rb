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

  # Factory Class to use when generating and saving objects
  config.object_factory = Bulkrax::ObjectFactory

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
      'funder' => { from: ['funder'], split: /\s*[;|]\s*/.freeze },
      'graduation_year' => { from: ['graduation_year'] },
      'identifier' => { from: ['identifier'], split: /\s*[;|]\s*/.freeze },
      'isbn' => { from: ['isbn'] },
      'issn' => { from: ['issn'], split: /\s*[;|]\s*/.freeze },
      'journal_issue' => { from: ['journal_issue'] },
      'journal_title' => { from: ['journal_title'] },
      'journal_volume' => { from: ['journal_volume'] },
      'keyword' => { from: ['keyword'], split: /\s*[;|]\s*/.freeze },
      'kind_of_data' => { from: ['kind_of_data'] },
      'language' => { from: ['language'] },
      'language_label' => { from: ['language_label'] },
      'last_modified_date' => { from: ['last_modified_date'] },
      'license' => { from: ['license'] },
      'license_label' => { from: ['license_label'] },
      'medium' => { from: ['medium'] },
      'methodology' => { from: ['methodology'] },
      'note' => { from: ['note'] },
      'page_end' => { from: ['page_end'] },
      'page_start' => { from: ['page_start'] },
      'parent' => { from: ['parent'], related_parents_field_mapping: true },
      'parent_title' => { from: ['parent_title'] },
      'peer_review_status' => { from: ['peer_review_status'] },
      'place_of_publication' => { from: ['place_of_publication'] },
      'publisher' => { from: ['publisher'] },
      'related_url' => { from: ['related_url'] },
      'resource_type' => { from: ['resource_type'] },
      'rights_holder' => { from: ['rights_holder'] },
      'rights_statement' => { from: ['rights_statement'] },
      'rights_statement_label' => { from: ['rights_statement_label'] },
      'series' => { from: ['series'] },
      'source' => { from: ['source'], source_identifier: true },
      'sponsor' => { from: ['sponsor'] },
      'subject' => { from: ['subject'] },
      'table_of_contents' => { from: ['table_of_contents'] },
      'title' => { from: ['title'], parsed: true },
      'url' => { from: ['url'] },
      'use' => { from: ['use'] },
      'file' => { from: ['file'] },
      'advisors_name' => { from: ['advisors_name'], object: 'advisors' },
      'advisors_id' => { from: ['advisors_id'], object: 'advisors' },
      'advisors_orcid' => { from: ['advisors_orcid'], object: 'advisors' },
      'advisors_affiliation' => { from: ['advisors_affiliation'], object: 'advisors' },
      'advisors_other_affiliation' => { from: ['advisors_other_affiliation'], object: 'advisors' },
      'advisors_index' => { from: ['advisors_index'], object: 'advisors' },
      'arrangers_name' => { from: ['arrangers_name'], object: 'arrangers' },
      'arrangers_id' => { from: ['arrangers_id'], object: 'arrangers' },
      'arrangers_orcid' => { from: ['arrangers_orcid'], object: 'arrangers' },
      'arrangers_affiliation' => { from: ['arrangers_affiliation'], object: 'arrangers' },
      'arrangers_other_affiliation' => { from: ['arrangers_other_affiliation'], object: 'arrangers' },
      'arrangers_index' => { from: ['arrangers_index'], object: 'arrangers' },
      'composers_name' => { from: ['composers_name'], object: 'composers' },
      'composers_id' => { from: ['composers_id'], object: 'composers' },
      'composers_orcid' => { from: ['composers_orcid'], object: 'composers' },
      'composers_affiliation' => { from: ['composers_affiliation'], object: 'composers' },
      'composers_other_affiliation' => { from: ['composers_other_affiliation'], object: 'composers' },
      'composers_index' => { from: ['composers_index'], object: 'composers' },
      'contributors_name' => { from: ['contributors_name'], object: 'contributors' },
      'contributors_id' => { from: ['contributors_id'], object: 'contributors' },
      'contributors_orcid' => { from: ['contributors_orcid'], object: 'contributors' },
      'contributors_affiliation' => { from: ['contributors_affiliation'], object: 'contributors' },
      'contributors_other_affiliation' => { from: ['contributors_other_affiliation'], object: 'contributors' },
      'contributors_index' => { from: ['contributors_index'], object: 'contributors' },
      'creators_name' => { from: ['creators_name'], object: 'creators' },
      'creators_id' => { from: ['creators_id'], object: 'creators' },
      'creators_orcid' => { from: ['creators_orcid'], object: 'creators' },
      'creators_affiliation' => { from: ['creators_affiliation'], object: 'creators' },
      'creators_other_affiliation' => { from: ['creators_other_affiliation'], object: 'creators' },
      'creators_index' => { from: ['creators_index'], object: 'creators' },
      'project_directors_name' => { from: ['project_directors_name'], object: 'project_directors' },
      'project_directors_id' => { from: ['project_directors_id'], object: 'project_directors' },
      'project_directors_orcid' => { from: ['project_directors_orcid'], object: 'project_directors' },
      'project_directors_affiliation' => { from: ['project_directors_affiliation'], object: 'project_directors' },
      'project_directors_other_affiliation' => { from: ['project_directors_other_affiliation'], object: 'project_directors' },
      'project_directors_index' => { from: ['project_directors_index'], object: 'project_directors' },
      'researchers_name' => { from: ['researchers_name'], object: 'researchers' },
      'researchers_id' => { from: ['researchers_id'], object: 'researchers' },
      'researchers_orcid' => { from: ['researchers_orcid'], object: 'researchers' },
      'researchers_affiliation' => { from: ['researchers_affiliation'], object: 'researchers' },
      'researchers_other_affiliation' => { from: ['researchers_other_affiliation'], object: 'researchers' },
      'researchers_index' => { from: ['researchers_index'], object: 'researchers' },
      'reviewers_name' => { from: ['reviewers_name'], object: 'reviewers' },
      'reviewers_id' => { from: ['reviewers_id'], object: 'reviewers' },
      'reviewers_orcid' => { from: ['reviewers_orcid'], object: 'reviewers' },
      'reviewers_affiliation' => { from: ['reviewers_affiliation'], object: 'reviewers' },
      'reviewers_other_affiliation' => { from: ['reviewers_other_affiliation'], object: 'reviewers' },
      'reviewers_index' => { from: ['reviewers_index'], object: 'reviewers' },
      'translators_name' => { from: ['translators_name'], object: 'translators' },
      'translators_id' => { from: ['translators_id'], object: 'translators' },
      'translators_orcid' => { from: ['translators_orcid'], object: 'translators' },
      'translators_affiliation' => { from: ['translators_affiliation'], object: 'translators' },
      'translators_other_affiliation' => { from: ['translators_other_affiliation'], object: 'translators' },
      'translators_index' => { from: ['translators_index'], object: 'translators' }
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
  # It is given two arguments, self at the time of call and the index of the record
  #    config.fill_in_blank_source_identifiers = ->(parser, index) { "b-#{parser.importer.id}-#{index}"}
  # or use a uuid
  config.fill_in_blank_source_identifiers = ->(parser, index) { SecureRandom.uuid }

  # Properties that should not be used in imports/exports. They are reserved for use by Hyrax.
  # config.reserved_properties += ['my_field']

  # List of Questioning Authority properties that are controlled via YAML files in
  # the config/authorities/ directory. For example, the :rights_statement property
  # is controlled by the active terms in config/authorities/rights_statements.yml
  # Defaults: 'rights_statement' and 'license'
  # config.qa_controlled_properties += ['my_field']

  # Specify the delimiter regular expression for splitting an attribute's values into a multi-value array.
  # NOTE: [hyc] this does not appear to work, so using split expressions on individual fields
  # config.multi_value_element_split_on = /\s*[;|]\s*/.freeze

  # Specify the delimiter for joining an attribute's multi-value array into a string.  Note: the
  # specific delimeter should likely be present in the multi_value_element_split_on expression.
  # config.multi_value_element_join_on = ' | '

  # Overriding removed_image_path which by default refers to a file in the spec folder
  config.removed_image_path = Rails.root.join('app', 'assets', 'images', 'bulkrax', 'removed.png')

  # Cleanup blank values during import
  Bulkrax::ObjectFactory.transformation_removes_blank_hash_values = true
end

# Sidebar for hyrax 3+ support
Hyrax::DashboardController.sidebar_partials[:repository_content] << 'hyrax/dashboard/sidebar/bulkrax_sidebar_additions' if Object.const_defined?(:Hyrax) && ::Hyrax::DashboardController&.respond_to?(:sidebar_partials)
