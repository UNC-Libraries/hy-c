# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/renderers/hyrax/renderers/attribute_renderer_override.rb')

RSpec.describe Hyrax::Renderers::AttributeRenderer do

  describe '#attribute_to_html' do
    subject { Nokogiri::HTML(renderer.render) }

    let(:expected) { Nokogiri::HTML(html_content) }

    context 'with language' do
      let(:field) { :language }
      let(:renderer) { described_class.new(field, ['http://id.loc.gov/vocabulary/iso639-2/eng']) }
      let(:html_content) do
        %(
          <p>Language</p>
          <ul class='tabular'>
            <li class=\"attribute attribute-language\">English</li>
          </ul>
        )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end
  end
end
