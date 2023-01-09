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
end
