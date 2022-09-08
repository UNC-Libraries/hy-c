# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/renderers/hyrax/renderers/attribute_renderer_override.rb')

RSpec.describe Hyrax::Renderers::AttributeRenderer do

  describe "#attribute_to_html" do
    subject { Nokogiri::HTML(renderer.render) }

    let(:expected) { Nokogiri::HTML(tr_content) }

    context 'with language' do
      let(:field) { :language }
      let(:renderer) { described_class.new(field, ['http://id.loc.gov/vocabulary/iso639-2/eng']) }
      let(:tr_content) do
        %(
          <tr>
          <th>Language</th>
          <td><ul class="tabular"><li class="attribute attribute-language">English</li></ul></td>
          </tr>
        )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end
  end
end
