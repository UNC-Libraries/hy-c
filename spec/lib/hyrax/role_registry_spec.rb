# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::RoleRegistry do  
  describe '#initialize' do
        it 'initializes with roles' do
            expected_roles = {
        'managing'  => 'Grants access to management tasks',
        'approving' => 'Grants access to approval tasks',
        'depositing' => 'Grants access to depositing tasks',
        'viewing' => 'Grants access to viewing tasks'
      }
            role_registry = described_class.new
            expect(role_registry.instance_variable_get(:@roles)).to eq(expected_roles)
        end
    end
end