# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Renderers::PersonAttributeRenderer do
  describe '#render_dl_row' do
    subject { Nokogiri::HTML(renderer.render_dl_row) }

    let(:expected) { Nokogiri::HTML(tr_content) }

    context 'with department a single term' do
      let(:field) { :creator_display }
      let(:renderer) { described_class.new(field, ['index:1||art, person||Affiliation: Art History']) }
      let(:tr_content) do
        %(
          <dt>Creator display</dt>
          <dd>
            <ul class="tabular">
              <li itemprop="creator" itemtype="http://schema.org/Person" class="attribute attribute-creator_display">
                <span>art, person</span>
                <ul>
                  <li>College of Arts and Sciences, Department of Art and Art History, Art History</li>
                </ul>
              </li>
            </ul>
          </dd>
        )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end

    context 'with department containing multiple terms' do
      let(:field) { :creator_display }
      let(:renderer) { described_class.new(field, ['index:1||person||Affiliation: Neurobiology Curriculum']) }
      let(:tr_content) do
        %(
          <dt>Creator display</dt>
          <dd>
            <ul class="tabular">
              <li itemprop="creator" itemtype="http://schema.org/Person" class="attribute attribute-creator_display">
                <span>person</span>
                <ul>
                  <li>School of Medicine, Neurobiology Curriculum</li>
                  <li>Neuroscience Center, Neurobiology Curriculum</li>
                </ul>
              </li>
            </ul>
          </dd>
        )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end

    context 'with creator with no affiliation' do
      let(:field) { :creator_display }
      let(:renderer) { described_class.new(field, ['index:1||lone, person||']) }
      let(:tr_content) do
        %(
          <dt>Creator display</dt>
          <dd>
            <ul class="tabular">
              <li itemprop="creator" itemtype="http://schema.org/Person" class="attribute attribute-creator_display">
                <span>lone, person</span>
              </li>
            </ul>
          </dd>
        )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end
  end
end
