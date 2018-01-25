require 'rails_helper'

RSpec.describe Hyrax::DepartmentsService do
  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns only active terms" do
      expect(service.select_all_options).to include(['Gillings School of Global Public Health',
                                                     ['Biostatistics', 'Environmental Sciences and Engineering',
                                                      'Epidemiology', 'Health Behavior', 'Health Policy and Management',
                                                      'Maternal and Child Health', 'Nutrition',
                                                      'Public Health Leadership Program']])
    end
  end
end

