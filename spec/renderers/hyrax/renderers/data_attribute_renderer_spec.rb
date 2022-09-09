# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/renderers/hyrax/renderers/date_attribute_renderer_override.rb')

RSpec.describe Hyrax::Renderers::DateAttributeRenderer do
  subject { Nokogiri::HTML(renderer.render) }

  let(:expected) { Nokogiri::HTML(content) }
  let(:field) { :embargo_release_date }

  describe '#attribute_to_html' do
    context 'with a UTC date' do
      let(:renderer) { described_class.new(field, ['2013-03-14T00:00:00Z']) }
      let(:content) do
        %(
        <tr>
        <th>Embargo release date</th>
        <td>
        <ul class="tabular">
        <li class="attribute attribute-embargo_release_date">March 14, 2013</li>
        </ul>
        </td>
        </tr>
      )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end

    context 'with an approximate date' do
      let(:renderer) { described_class.new(field, ['201x']) }
      let(:content) do
        %(
          <tr>
          <th>Embargo release date</th>
          <td>
          <ul class="tabular">
          <li class="attribute attribute-embargo_release_date">2010s</li>
          </ul>
          </td>
          </tr>
      )
      end

      it { expect(subject).to be_equivalent_to(expected) }
    end
  end

  context 'with an invalid date' do
    let(:renderer) { described_class.new(field, ['invalid']) }
    let(:content) do
      %(
        <tr>
        <th>Embargo release date</th>
        <td>
        <ul class="tabular">
        <li class="attribute attribute-embargo_release_date">invalid</li>
        </ul>
        </td>
        </tr>
      )
    end

    it { expect(subject).to be_equivalent_to(expected) }
  end
end
