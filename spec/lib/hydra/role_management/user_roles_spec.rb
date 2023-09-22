# frozen_string_literal: true
require 'rails_helper'

describe Hydra::RoleManagement::UserRoles do
  let(:librarian) { Role.create!(name: 'librarian') }

  describe '#admin_unit_manager?' do
    subject(:user) do
      User.create!(email: 'fred@example.com', uid: 'fred@example.com', password: 'password')
    end

    before do
      user.roles << librarian
    end

    it 'returns true for existing group name' do
      expect(subject.admin_unit_manager?('librarian')).to be_truthy
    end

    it 'returns false for non-existent group' do
      expect(subject.admin_unit_manager?('secret_agents')).to be_falsey
    end
  end
end
