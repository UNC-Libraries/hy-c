# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Forms::PermissionTemplateForm do
  describe '#roles_for_agent' do
    let(:permission_template) { FactoryBot.create(:permission_template) }
    let(:permission_template_form) { described_class.new(permission_template: permission_template) }
    let(:grants_as_collection) { [
        Hyrax::PermissionTemplateAccess::DEPOSIT, Hyrax::PermissionTemplateAccess::VIEW, Hyrax::PermissionTemplateAccess::MANAGE
    ]
    }
      # let(:role_names) { Hyrax::RoleRegistry.new.role_names }
      # let(:roles) { Sipity::Role.where(name: role_names) }
    let(:depositing_role) { Sipity::Role.find_by(name: Hyrax::RoleRegistry::DEPOSITING) }
    let(:viewing_role) { Sipity::Role.find_by(name: Hyrax::RoleRegistry::VIEWING) }

      # before do
      #     allow(permission_template_form).to receive(:grants_as_collection).and_return(grants_as_collection)
      # end

    it 'when access is deposit returns the depositing role' do
      allow(permission_template_form).to receive(:grants_as_collection).and_return([Hyrax::PermissionTemplateAccess::DEPOSIT])
      expect(permission_template_form.roles_for_agent).to eq [depositing_role]
    end

    # context
  end
end
