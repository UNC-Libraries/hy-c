# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Renderers::PersonAttributeRenderer do
  describe '#attribute_to_html' do
    subject { Nokogiri::HTML(renderer.render) }

    let(:expected) { Nokogiri::HTML(tr_content) }

    context 'with department containing multiple terms' do
      let(:field) { :creator_display }
      let(:renderer) { described_class.new(field, ['index:1||person||Affiliation: Joint Department of Biomedical Engineering']) }
      let(:tr_content) do
        %(
          <li>
            <span>person</span>
            <ul>
              <li>School of Medicine; Joint Department of Biomedical Engineering</li>
              <li>North Carolina State University; Joint Department of Biomedical Engineering</li>
            </ul>
          </li>
        )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end
  end
end
