# frozen_string_literal: true
require 'rails_helper'
module Bulkrax
  RSpec.describe ObjectFactory do
    describe 'transform_attributes' do
      subject { described_class.new(attributes: attributes,
                                    source_identifier_value: '9p2909328',
                                    work_identifier: '9p2909328',
                                    klass: General)
      }

      context 'with record containing people objects' do
        let(:attributes) {
          {
            'title'=>['Test Work 1'],
            'creators'=>[{
               'creators_affiliation'=>'Department of Biology',
               'creators_id'=>'#nested_persong635480',
               'creators_index'=>'2',
               'creators_name'=>'Biology Creator',
               'creators_orcid'=>'',
               'creators_other_affiliation'=>''
             }, {
               'creators_affiliation'=>'Department of Medicine',
               'creators_id'=>'#nested_persong635481',
               'creators_index'=>'1',
               'creators_name'=>'Medicine Creator',
               'creators_orcid'=>'',
               'creators_other_affiliation'=>'School of Testing'
             }],
             'id'=>'9p2909328'
           }
        }

        it 'moves creators to creators_attributes and changes to hash with numeric indexes' do
          transformed = subject.send(:transform_attributes)
          expect(transformed['title']).to eq ['Test Work 1']
          expect(transformed).to_not have_key('creators')
          expect(transformed['creators_attributes']['0']).to include({
            'affiliation'=>'Department of Biology',
            'id'=>'#nested_persong635480',
            'index'=>'2',
            'name'=>'Biology Creator',
            'orcid'=>'',
            'other_affiliation'=>''
          })
          expect(transformed['creators_attributes']['1']).to include({
            'affiliation'=>'Department of Medicine',
            'id'=>'#nested_persong635481',
            'index'=>'1',
            'name'=>'Medicine Creator',
            'orcid'=>'',
            'other_affiliation'=>'School of Testing'
          })
          expect(transformed['creators_attributes'].length).to eq 2
        end
      end

      context 'with record single value field that should be multi valued' do
        let(:attributes) {
          {
            'title'=>['Test Work 2'],
            'abstract'=>['Testing factory'],
            'date_issued'=>'12/20/22',
             'id'=>'9p2909328',
           }
        }

        it 'wraps field value in array' do
          transformed = subject.send(:transform_attributes)
          expect(transformed['date_issued']).to eq ['12/20/22']
        end
      end

      context 'with record multi value field that should be single valued' do
        let(:attributes) {
          {
            'title'=>['Test Work 3'],
            'admin_note'=>['Note 1', 'Note 2'],
             'id'=>'9p2909328',
           }
        }

        it 'replaces array with first value' do
          transformed = subject.send(:transform_attributes)
          expect(transformed['admin_note']).to eq 'Note 1'
        end
      end
    end
  end
end
