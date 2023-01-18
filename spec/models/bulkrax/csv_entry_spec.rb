# frozen_string_literal: true
# rubocop: disable Metrics/BlockLength

require 'rails_helper'

module Bulkrax
  RSpec.describe CsvEntry, type: :model do
    class Work < ActiveFedora::Base
      include ::Hyrax::WorkBehavior
      property :single_object, predicate: ::RDF::Vocab::DC.creator, multiple: false
      property :multiple_objects, predicate: ::RDF::Vocab::DC.creator

      property :license, predicate: ::RDF::Vocab::DC.rights
      property :rights_statement, predicate: ::RDF::Vocab::EDM.rights
    end

    describe 'builds entry' do
      let(:hyrax_record) do
        OpenStruct.new(
          file_sets: [],
          member_of_collections: [],
          member_of_work_ids: [],
          in_work_ids: [],
          member_work_ids: []
        )
      end

      before do
        allow_any_instance_of(described_class).to receive(:collections_created?).and_return(true)
        # allow_any_instance_of(described_class).to receive(:find_collection).and_return(collection)
        allow(subject).to receive(:hyrax_record).and_return(hyrax_record)
      end
      let(:importer) { FactoryBot.create(:bulkrax_importer_csv) }
      subject { described_class.new(importerexporter: importer) }

      describe 'single valued field with controlled vocabulary' do
        let(:original_value) { 'http://example.com/obj/' }
        let(:corrected_value) { 'https://example.com/obj/' }
        # Mock 'single_object' as a controlled vocab field
        before do
          allow(Bulkrax).to receive(:qa_controlled_properties).and_return(['rights_statement'])
          allow(subject).to receive(:raw_metadata).and_return('rights_statement' => original_value, 'source' => 'qa_1', 'title' => 'some title', 'model' => 'General')
          allow(subject).to receive(:active_id_for_authority?).with(original_value, 'rights_statement').and_return(false)
          allow(subject).to receive(:active_id_for_authority?).with(corrected_value, 'rights_statement').and_return(true)
        end

        it 'replaces http with https for single valued field' do
          subject.build_metadata

          expect(subject.parsed_metadata['rights_statement']).to eq(corrected_value)
        end
      end

      describe 'single valued field with controlled vocabulary empty value' do
        let(:original_value) { '' }
        let(:corrected_value) { nil }
        # Mock 'single_object' as a controlled vocab field
        before do
          allow(Bulkrax).to receive(:qa_controlled_properties).and_return(['rights_statement'])
          allow(subject).to receive(:raw_metadata).and_return('rights_statement' => original_value, 'source' => 'qa_1', 'title' => 'some title', 'model' => 'General')
          allow(subject).to receive(:active_id_for_authority?).with(original_value, 'rights_statement').and_return(false)
          allow(subject).to receive(:active_id_for_authority?).with(corrected_value, 'rights_statement').and_return(true)
        end

        it 'replaces blank rights_statement with single valued default' do
          subject.build_metadata

          expect(subject.parsed_metadata['rights_statement']).to eq(corrected_value)
        end
      end
    end

    describe 'reads entry' do
      subject { described_class.new(importerexporter: exporter) }

      context 'with people object fields prefixed' do
        let(:exporter) do
          FactoryBot.create(:bulkrax_exporter_worktype, field_mapping: {
                              'id' => { from: ['id'], source_identifier: true },
                              'title' => { from: ['title'], parsed: true },
                              'creators_name' => { from: ['creators_name'], object: 'creators' },
                              'creators_id' => { from: ['creators_id'], object: 'creators' },
                              'creators_orcid' => { from: ['creators_orcid'], object: 'creators' },
                              'creators_affiliation' => { from: ['creators_affiliation'], object: 'creators' },
                              'creators_other_affiliation' => { from: ['creators_other_affiliation'], object: 'creators' },
                              'creators_index' => { from: ['creators_index'], object: 'creators' },
                              'advisors_name' => { from: ['advisors_name'], object: 'advisors' },
                              'advisors_id' => { from: ['advisors_id'], object: 'advisors' },
                              'advisors_orcid' => { from: ['advisors_orcid'], object: 'advisors' },
                              'advisors_affiliation' => { from: ['advisors_affiliation'], object: 'advisors' },
                              'advisors_other_affiliation' => { from: ['advisors_other_affiliation'], object: 'advisors' }
                            })
        end

        context 'with general work with multiple people' do
          let(:work_obj) do
            General.new(title: ['new test bulkrax work'],
                        creators_attributes: {
                          '0' => {
                            'name' => 'Doe, John',
                            'affiliation' => 'Department of Biology',
                            'orcid' => 'some orcid'
                          },
                          '1' => {
                            'name' => 'Hy, C',
                            'affiliation' => 'Department of Computer Science'
                          }},
                        advisors_attributes: {
                          '0' => {
                            'name' => 'Ad, Visor',
                            'affiliation' => 'Department of Medicine'
                          }})
          end

          before do
            allow_any_instance_of(ObjectFactory).to receive(:run!)
            allow(subject).to receive(:hyrax_record).and_return(work_obj)
            allow(work_obj).to receive(:id).and_return('test123')
            allow(work_obj).to receive(:member_of_work_ids).and_return([])
            allow(work_obj).to receive(:in_work_ids).and_return([])
            allow(work_obj).to receive(:member_work_ids).and_return([])
          end

          it 'succeeds' do
            metadata = subject.build_export_metadata
            expect(metadata['creators_name_1']).to eq('Doe, John')
            expect(metadata['creators_affiliation_1']).to eq('Department of Biology')
            expect(metadata['creators_orcid_1']).to eq('some orcid')
            expect(metadata['creators_name_2']).to eq('Hy, C')
            expect(metadata['creators_affiliation_2']).to eq('Department of Computer Science')
            expect(metadata['creators_orcid_2']).to be_nil
            expect(metadata['advisors_name_1']).to eq('Ad, Visor')
            expect(metadata['advisors_affiliation_1']).to eq('Department of Medicine')
            expect(metadata['advisors_orcid_1']).to be_nil
            expect(metadata['title_1']).to eq('new test bulkrax work')
          end
        end

        context 'with work type that does not support advisors' do
          let(:work_obj) do
            Article.new(title: ['new test bulkrax article'],
                        creators_attributes: {
                          '0' => {
                            'name' => 'Doe, John',
                            'affiliation' => 'Department of Biology',
                            'orcid' => 'some orcid'
                          }})
          end

          before do
            allow_any_instance_of(ObjectFactory).to receive(:run!)
            allow(subject).to receive(:hyrax_record).and_return(work_obj)
            allow(work_obj).to receive(:id).and_return('test123')
            allow(work_obj).to receive(:member_of_work_ids).and_return([])
            allow(work_obj).to receive(:in_work_ids).and_return([])
            allow(work_obj).to receive(:member_work_ids).and_return([])
          end

          it 'succeeds' do
            metadata = subject.build_export_metadata
            expect(metadata['creators_name_1']).to eq('Doe, John')
            expect(metadata['creators_affiliation_1']).to eq('Department of Biology')
            expect(metadata['creators_orcid_1']).to eq('some orcid')
            expect(metadata['title_1']).to eq('new test bulkrax article')
          end
        end
      end

      context 'with object fields prefixed' do
        let(:exporter) do
          FactoryBot.create(:bulkrax_exporter_worktype, field_mapping: {
                              'id' => { from: ['id'], source_identifier: true },
                              'single_object_first_name' => { from: ['single_object_first_name'], object: 'single_object' },
                              'single_object_last_name' => { from: ['single_object_last_name'], object: 'single_object' },
                              'single_object_position' => { from: ['single_object_position'], object: 'single_object' },
                              'single_object_language' => { from: ['single_object_language'], object: 'single_object', parsed: true }
                            })
        end

        let(:work_obj) do
          Work.new(
            title: ['test'],
            single_object: [{
              'single_object_first_name' => 'Fake',
              'single_object_last_name' => 'Fakerson',
              'single_object_position' => 'Leader, Jester, Queen',
              'single_object_language' => 'english'
            }].to_s
          )
        end

        before do
          allow_any_instance_of(ObjectFactory).to receive(:run!)
          allow(subject).to receive(:hyrax_record).and_return(work_obj)
          allow(work_obj).to receive(:id).and_return('test123')
          allow(work_obj).to receive(:member_of_work_ids).and_return([])
          allow(work_obj).to receive(:in_work_ids).and_return([])
          allow(work_obj).to receive(:member_work_ids).and_return([])
        end

        it 'succeeds' do
          metadata = subject.build_export_metadata
          expect(metadata['single_object_first_name_1']).to eq('Fake')
          expect(metadata['single_object_last_name_1']).to eq('Fakerson')
          expect(metadata['single_object_position_1']).to include('Leader', 'Jester', 'Queen')
          expect(metadata['single_object_language_1']).to eq('english')
        end
      end

      context 'with object fields and no prefix' do
        let(:exporter) do
          FactoryBot.create(:bulkrax_exporter_worktype, field_mapping: {
                              'id' => { from: ['id'], source_identifier: true },
                              'first_name' => { from: ['single_object_first_name'], object: 'single_object' },
                              'last_name' => { from: ['single_object_last_name'], object: 'single_object' },
                              'position' => { from: ['single_object_position'], object: 'single_object' },
                              'language' => { from: ['single_object_language'], object: 'single_object', parsed: true }
                            })
        end

        let(:work_obj) do
          Work.new(
            title: ['test'],
            single_object: [{
              'first_name' => 'Fake',
              'last_name' => 'Fakerson',
              'position' => 'Leader, Jester, Queen',
              'language' => 'english'
            }].to_s
          )
        end

        before do
          allow_any_instance_of(ObjectFactory).to receive(:run!)
          allow(subject).to receive(:hyrax_record).and_return(work_obj)
          allow(work_obj).to receive(:id).and_return('test123')
          allow(work_obj).to receive(:member_of_work_ids).and_return([])
          allow(work_obj).to receive(:in_work_ids).and_return([])
          allow(work_obj).to receive(:member_work_ids).and_return([])
        end

        it 'succeeds' do
          metadata = subject.build_export_metadata
          expect(metadata['single_object_first_name_1']).to eq('Fake')
          expect(metadata['single_object_last_name_1']).to eq('Fakerson')
          expect(metadata['single_object_position_1']).to include('Leader', 'Jester', 'Queen')
          expect(metadata['single_object_language_1']).to eq('english')
        end
      end

      context 'with multiple objects and fields prefixed' do
        let(:exporter) do
          FactoryBot.create(:bulkrax_exporter_worktype, field_mapping: {
                              'id' => { from: ['id'], source_identifier: true },
                              'multiple_objects_first_name' => { from: ['multiple_objects_first_name'], object: 'multiple_objects' },
                              'multiple_objects_last_name' => { from: ['multiple_objects_last_name'], object: 'multiple_objects' },
                              'multiple_objects_position' => { from: ['multiple_objects_position'], object: 'multiple_objects' },
                              'multiple_objects_language' => { from: ['multiple_objects_language'], object: 'multiple_objects', parsed: true }
                            })
        end

        let(:work_obj) do
          Work.new(
            title: ['test'],
            multiple_objects: [
              [
                {
                  'multiple_objects_first_name' => 'Fake',
                  'multiple_objects_last_name' => 'Fakerson',
                  'multiple_objects_position' => 'Leader, Jester, Queen',
                  'multiple_objects_language' => 'english'
                },
                {
                  'multiple_objects_first_name' => 'Judge',
                  'multiple_objects_last_name' => 'Hines',
                  'multiple_objects_position' => 'King, Lord, Duke'
                }
              ].to_s
            ]
          )
        end

        before do
          allow_any_instance_of(ObjectFactory).to receive(:run!)
          allow(subject).to receive(:hyrax_record).and_return(work_obj)
          allow(work_obj).to receive(:id).and_return('test123')
          allow(work_obj).to receive(:member_of_work_ids).and_return([])
          allow(work_obj).to receive(:in_work_ids).and_return([])
          allow(work_obj).to receive(:member_work_ids).and_return([])
        end

        it 'succeeds' do
          metadata = subject.build_export_metadata
          expect(metadata['multiple_objects_first_name_1']).to eq('Fake')
          expect(metadata['multiple_objects_last_name_1']).to eq('Fakerson')
          expect(metadata['multiple_objects_position_1']).to include('Leader, Jester, Queen')
          expect(metadata['multiple_objects_language_1']).to eq('english')
          expect(metadata['multiple_objects_first_name_2']).to eq('Judge')
          expect(metadata['multiple_objects_last_name_2']).to eq('Hines')
          expect(metadata['multiple_objects_position_2']).to include('King, Lord, Duke')
        end
      end

      context 'with multiple objects and no fields prefixed' do
        let(:exporter) do
          FactoryBot.create(:bulkrax_exporter_worktype, field_mapping: {
                              'id' => { from: ['id'], source_identifier: true },
                              'first_name' => { from: ['multiple_objects_first_name'], object: 'multiple_objects' },
                              'last_name' => { from: ['multiple_objects_last_name'], object: 'multiple_objects' },
                              'position' => { from: ['multiple_objects_position'], object: 'multiple_objects' },
                              'language' => { from: ['multiple_objects_language'], object: 'multiple_objects', parsed: true }
                            })
        end

        let(:work_obj) do
          Work.new(
            title: ['test'],
            multiple_objects: [
              [
                {
                  'first_name' => 'Fake',
                  'last_name' => 'Fakerson',
                  'position' => 'Leader, Jester, Queen',
                  'language' => 'english'
                },
                {
                  'first_name' => 'Judge',
                  'last_name' => 'Hines',
                  'position' => 'King, Lord, Duke'
                }
              ].to_s
            ]
          )
        end

        before do
          allow_any_instance_of(ObjectFactory).to receive(:run!)
          allow(subject).to receive(:hyrax_record).and_return(work_obj)
          allow(work_obj).to receive(:id).and_return('test123')
          allow(work_obj).to receive(:member_of_work_ids).and_return([])
          allow(work_obj).to receive(:in_work_ids).and_return([])
          allow(work_obj).to receive(:member_work_ids).and_return([])
        end

        it 'succeeds' do
          metadata = subject.build_export_metadata
          expect(metadata['multiple_objects_first_name_1']).to eq('Fake')
          expect(metadata['multiple_objects_last_name_1']).to eq('Fakerson')
          expect(metadata['multiple_objects_position_1']).to include('Leader, Jester, Queen')
          expect(metadata['multiple_objects_language_1']).to eq('english')
          expect(metadata['multiple_objects_first_name_2']).to eq('Judge')
          expect(metadata['multiple_objects_last_name_2']).to eq('Hines')
          expect(metadata['multiple_objects_position_2']).to include('King, Lord, Duke')
        end
      end

      context 'with object fields prefixed and properties with multiple values' do
        let(:exporter) do
          FactoryBot.create(:bulkrax_exporter_worktype, field_mapping: {
                              'id' => { from: ['id'], source_identifier: true },
                              'multiple_objects_first_name' => { from: ['multiple_objects_first_name'], object: 'multiple_objects' },
                              'multiple_objects_last_name' => { from: ['multiple_objects_last_name'], object: 'multiple_objects' },
                              'multiple_objects_position' => { from: ['multiple_objects_position'], object: 'multiple_objects', nested_type: 'Array' }
                            })
        end

        let(:work_obj) do
          Work.new(
            title: ['test'],
            multiple_objects: [
              [
                {
                  'multiple_objects_first_name' => 'Fake',
                  'multiple_objects_last_name' => 'Fakerson'
                },
                {
                  'multiple_objects_first_name' => 'Judge',
                  'multiple_objects_last_name' => 'Hines',
                  'multiple_objects_position' => ['King', 'Lord', 'Duke']
                }
              ].to_s
            ]
          )
        end

        before do
          allow_any_instance_of(ObjectFactory).to receive(:run!)
          allow(subject).to receive(:hyrax_record).and_return(work_obj)
          allow(work_obj).to receive(:id).and_return('test123')
          allow(work_obj).to receive(:member_of_work_ids).and_return([])
          allow(work_obj).to receive(:in_work_ids).and_return([])
          allow(work_obj).to receive(:member_work_ids).and_return([])
        end

        it 'succeeds' do
          metadata = subject.build_export_metadata
          expect(metadata['multiple_objects_first_name_1']).to eq('Fake')
          expect(metadata['multiple_objects_last_name_1']).to eq('Fakerson')
          expect(metadata['multiple_objects_first_name_2']).to eq('Judge')
          expect(metadata['multiple_objects_last_name_2']).to eq('Hines')
          expect(metadata['multiple_objects_position_2_1']).to eq('King')
          expect(metadata['multiple_objects_position_2_2']).to eq('Lord')
          expect(metadata['multiple_objects_position_2_3']).to eq('Duke')
        end
      end

      context 'with object fields not prefixed and properties with multiple values' do
        let(:exporter) do
          FactoryBot.create(:bulkrax_exporter_worktype, field_mapping: {
                              'id' => { from: ['id'], source_identifier: true },
                              'first_name' => { from: ['multiple_objects_first_name'], object: 'multiple_objects' },
                              'last_name' => { from: ['multiple_objects_last_name'], object: 'multiple_objects' },
                              'position' => { from: ['multiple_objects_position'], object: 'multiple_objects', nested_type: 'Array' }
                            })
        end

        let(:work_obj) do
          Work.new(
            title: ['test'],
            multiple_objects: [
              [
                {
                  'first_name' => 'Fake',
                  'last_name' => 'Fakerson'
                },
                {
                  'first_name' => 'Judge',
                  'last_name' => 'Hines',
                  'position' => ['King', 'Lord', 'Duke']
                }
              ].to_s
            ]
          )
        end

        before do
          allow_any_instance_of(ObjectFactory).to receive(:run!)
          allow(subject).to receive(:hyrax_record).and_return(work_obj)
          allow(work_obj).to receive(:id).and_return('test123')
          allow(work_obj).to receive(:member_of_work_ids).and_return([])
          allow(work_obj).to receive(:in_work_ids).and_return([])
          allow(work_obj).to receive(:member_work_ids).and_return([])
        end

        it 'succeeds' do
          metadata = subject.build_export_metadata
          expect(metadata['multiple_objects_first_name_1']).to eq('Fake')
          expect(metadata['multiple_objects_last_name_1']).to eq('Fakerson')
          expect(metadata['multiple_objects_first_name_2']).to eq('Judge')
          expect(metadata['multiple_objects_last_name_2']).to eq('Hines')
          expect(metadata['multiple_objects_position_2_1']).to eq('King')
          expect(metadata['multiple_objects_position_2_2']).to eq('Lord')
          expect(metadata['multiple_objects_position_2_3']).to eq('Duke')
        end
      end
    end
  end
end
# rubocop: enable Metrics/BlockLength
