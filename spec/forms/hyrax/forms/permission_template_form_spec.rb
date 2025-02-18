# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Forms::PermissionTemplateForm do
  describe '#roles_for_agent' do
    let(:permission_template) { FactoryBot.create(:permission_template) }
    let(:permission_template_form) { described_class.new(permission_template) }
    let(:all_permissions) { [
        { access: Hyrax::PermissionTemplateAccess::DEPOSIT },
        { access: Hyrax::PermissionTemplateAccess::MANAGE },
        { access: Hyrax::PermissionTemplateAccess::VIEW },
    ]
    }
    let(:managing_role) { Sipity::Role.find_by(name: Hyrax::RoleRegistry::MANAGING) }
    let(:depositing_role) { Sipity::Role.find_by(name: Hyrax::RoleRegistry::DEPOSITING) }
    let(:viewing_role) { Sipity::Role.find_by(name: Hyrax::RoleRegistry::VIEWING) }


    before do
      Sipity::Role.create!(name: 'managing', description: 'Grants access to management tasks')
      Sipity::Role.create!(name: 'depositing', description: 'Grants access to depositing tasks')
      Sipity::Role.create!(name: 'viewing', description: 'Grants access to viewing tasks')
    end

    it 'returns all roles when manage access is granted' do
      allow(permission_template_form).to receive(:grants_as_collection).and_return([{ access: Hyrax::PermissionTemplateAccess::MANAGE }])
      expect(permission_template_form.roles_for_agent).to include(managing_role, depositing_role, viewing_role)
    end

    it 'returns the depositing role when deposit access is granted' do
      allow(permission_template_form).to receive(:grants_as_collection).and_return([{ access: Hyrax::PermissionTemplateAccess::DEPOSIT }])
      expect(permission_template_form.roles_for_agent).to eq [depositing_role]
    end

    it 'returns the viewing role when view access is granted' do
      allow(permission_template_form).to receive(:grants_as_collection).and_return([{ access: Hyrax::PermissionTemplateAccess::VIEW }])
      expect(permission_template_form.roles_for_agent).to eq [viewing_role]
    end

    it 'applies all roles when all permissions are present' do
      allow(permission_template_form).to receive(:grants_as_collection).and_return(all_permissions)
      expect(permission_template_form.roles_for_agent).to include(managing_role, depositing_role, viewing_role)
    end
  end
end
