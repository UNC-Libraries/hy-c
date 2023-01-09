# frozen_string_literal: true

FactoryBot.define do
  factory :bulkrax_exporter_worktype, class: 'Bulkrax::Exporter' do
    name { 'Export from Worktype' }
    user { FactoryBot.build(:user) }
    export_type { 'metadata' }
    export_from { 'worktype' }
    export_source { 'Generic' }
    parser_klass { 'Bulkrax::CsvParser' }
    limit { 0 }
    field_mapping { nil }
    generated_metadata { false }
  end

  factory :bulkrax_importer_csv, class: 'Bulkrax::Importer' do
    name { 'CSV Import' }
    admin_set_id { 'MyString' }
    user { FactoryBot.build(:user) }
    frequency { 'PT0S' }
    parser_klass { 'Bulkrax::CsvParser' }
    limit { 10 }
    parser_fields { { 'import_file_path' => 'spec/fixtures/csv/good.csv' } }
    field_mapping { {} }
    after :create, &:current_run

    trait :with_relationships_mappings do
      field_mapping do
        {
          'parents' => { 'from' => ['parents_column'], split: /\s*[|]\s*/, related_parents_field_mapping: true },
          'children' => { 'from' => ['children_column'], split: /\s*[|]\s*/, related_children_field_mapping: true }
        }
      end
    end
  end
end
