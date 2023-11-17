# frozen_string_literal: true
require 'rails_helper'

require Rails.root.join('app/overrides/actors/hyrax/actors/base_actor_override.rb')

RSpec.describe Hyrax::Actors::BaseActor do
  before do
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?).and_return(false)
    Sipity::WorkflowState.create(workflow_id: workflow.id, name: 'deposited')
  end

  let(:depositor) { FactoryBot.create(:user) }
  let(:admin_set) { AdminSet.create(title: ['an admin set']) }

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  describe '#update' do
    context 'update work with non-admin non-depositor view permission' do
      let!(:basic_user) { FactoryBot.create(:user) }
      let(:ability) { ::Ability.new(depositor) }

      let(:work) {
        General.create(title: ['work for sharing'],
                            depositor: depositor.email,
                            admin_set_id: admin_set.id)
      }
      let(:file_set1) { FactoryBot.create(:file_set) }

      let!(:entity) { Sipity::Entity.create(proxy_for_global_id: work.to_global_id.to_s, workflow_id: workflow.id) }

      let(:terminator) { Hyrax::Actors::Terminator.new }

      subject(:middleware) do
        stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
          middleware.use Hyrax::Actors::CreateWithFilesActor
          middleware.use Hyrax::Actors::AddToWorkActor
          middleware.use Hyrax::Actors::InterpretVisibilityActor
          middleware.use Hyrax::Actors::GeneralActor
        end
        stack.build(terminator)
      end

      let(:attributes) {
        {
          permissions_attributes: {
            "0": {
              type: 'person',
              name: basic_user.email,
              access: 'read'
            }
          }
        }
      }

      before do
        allow(terminator).to receive(:update).and_return(true)
        work.ordered_members << file_set1
      end

      it 'adds the user permission to the work' do
        env = Hyrax::Actors::Environment.new(work, ability, attributes)
        middleware.update(env)

        user_perm = work.permissions.to_a.find { |perm| perm.agent.first.id == "http://projecthydra.org/ns/auth/person##{basic_user.email}" }
        expect(user_perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Read'
      end
    end
  end
end
