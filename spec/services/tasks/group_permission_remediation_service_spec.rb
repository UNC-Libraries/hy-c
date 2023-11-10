# frozen_string_literal: true
require 'rails_helper'
include Warden::Test::Helpers

describe Tasks::GroupPermissionRemediationService, :clean do
  before do
    ActiveFedora::Cleaner.clean!
  end

  let(:admin) { FactoryBot.create(:admin) }

  let(:admin_set) do
    AdminSet.create(title: ['proquest admin set'],
                    description: ['some description'])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  describe '#run' do
    context 'with groups assigned to admin set' do
      let(:id_list_file) { Tempfile.new }

      let(:manager) do
        FactoryBot.create(:user, email: 'manager@example.com', guest: false, uid: 'manager')
      end
      let(:viewer) do
        FactoryBot.create(:user, email: 'viewer@example.com', guest: false, uid: 'viewer')
      end
      let(:manager_agent) { Sipity::Agent.where(proxy_for_id: 'oa_manager', proxy_for_type: 'Hyrax::Group').first_or_create }
      let(:viewer_agent) { Sipity::Agent.where(proxy_for_id: 'oa_viewer', proxy_for_type: 'Hyrax::Group').first_or_create }

      let(:article) { FactoryBot.create(:article) }
      let(:file_set1) { FactoryBot.create(:file_set) }
      let(:file_set2) { FactoryBot.create(:file_set, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE) }

      before do
        Article.delete_all

        Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                               agent_type: 'group',
                                               agent_id: 'oa_manager',
                                               access: 'manage')
        Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                               agent_type: 'group',
                                               agent_id: 'oa_viewer',
                                               access: 'view')
        Hyrax::Workflow::PermissionGenerator.call(roles: 'managing', workflow: workflow, agents: manager_agent)
        Hyrax::Workflow::PermissionGenerator.call(roles: 'viewing', workflow: workflow, agents: viewer_agent)
        manager_role = Role.where(name: 'oa_manager').first_or_create
        manager_role.users << manager
        manager_role.save
        viewer_role = Role.where(name: 'oa_viewer').first_or_create
        viewer_role.users << viewer
        viewer_role.save

        File.write(id_list_file, article.id)

        article.ordered_members << file_set1
        article.ordered_members << file_set2
      end

      after do
        id_list_file.unlink
      end


      it 'adds group roles from admin set to work and file set' do
        Tasks::GroupPermissionRemediationService.run(id_list_file.path, admin_set.id)

        article = Article.first
        expect_to_have_permissions(article)

        article_file_sets = article.file_sets
        expect(article_file_sets.length).to eq 2
        expect_to_have_permissions(article_file_sets[0])
        expect_to_have_permissions(article_file_sets[1])
        expect(article_file_sets[1].visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      end

      def expect_to_have_permissions(item)
        manager_perm = item.permissions.to_a.find { |perm| perm.agent.first.id == 'http://projecthydra.org/ns/auth/group#oa_manager' }
        expect(manager_perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Write'

        pub_perm = item.permissions.to_a.find { |perm| perm.agent.first.id == 'http://projecthydra.org/ns/auth/group#oa_viewer' }
        expect(pub_perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Read'
      end
    end
  end
end
