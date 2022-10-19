# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::WorkFormHelper do
  let(:dummy_class) { Class.new { include Hyrax::WorkFormHelper } }
  subject { dummy_class.new }

  describe '#form_tabs_for' do
    context 'with BatchUploadForm' do
      let(:work) { General.new }
      let(:ability) { double }
      let(:form) { Hyrax::Forms::BatchUploadForm.new(work, ability, controller) }

      it 'returns tabs containing files' do
        expect(subject.form_tabs_for(form: form)).to eq (%w[files metadata relationships])
      end
    end

    context 'with other form' do
      let(:form) { instance_double(Hyrax::Forms::WorkForm) }

      it 'returns tabs without files' do
        expect(subject.form_tabs_for(form: form)).to eq (%w[metadata relationships])
      end
    end
  end
end