# frozen_string_literal: true
# spec/helpers/affiliation_utils_helper_spec.rb
require 'rails_helper'

RSpec.describe AffiliationUtilsHelper do
  describe '.is_unc_affiliation?' do
    context 'with UNC Chapel Hill variations' do
      it 'returns true for "UNC Chapel Hill"' do
        expect(described_class.is_unc_affiliation?('UNC Chapel Hill')).to be true
      end

      it 'returns true for "UNC-Chapel Hill"' do
        expect(described_class.is_unc_affiliation?('UNC-Chapel Hill')).to be true
      end

      it 'returns true for "University of North Carolina at Chapel Hill"' do
        expect(described_class.is_unc_affiliation?('University of North Carolina at Chapel Hill')).to be true
      end

      it 'returns true for "University of N Carolina Chapel Hill"' do
        expect(described_class.is_unc_affiliation?('University of N Carolina Chapel Hill')).to be true
      end

      it 'returns true for "Univ of North Carolina at Chapel Hill"' do
        expect(described_class.is_unc_affiliation?('Univ of North Carolina at Chapel Hill')).to be true
      end

      it 'returns true for "UNCCH Department of Epidemiology"' do
        expect(described_class.is_unc_affiliation?('UNCCH Department of Epidemiology')).to be true
      end
    end

    context 'with unrelated institutions' do
      it 'returns false for "Duke University"' do
        expect(described_class.is_unc_affiliation?('Duke University')).to be false
      end

      it 'returns false for "University of South Carolina"' do
        expect(described_class.is_unc_affiliation?('University of South Carolina')).to be false
      end

      it 'returns false for empty string' do
        expect(described_class.is_unc_affiliation?('')).to be false
      end

      it 'returns false for nil' do
        expect(described_class.is_unc_affiliation?(nil)).to be false
      end
    end
  end
end
