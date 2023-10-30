# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::WorksControllerBehavior, type: :controller do
  let(:paths) { controller.main_app }

  controller(ApplicationController) do
    include Hyrax::WorksControllerBehavior # rubocop:disable RSpec/DescribedClass

    self.curation_concern_type = General
  end

  describe '#available_admin_sets' do
    context 'with a logged in user' do
      before { sign_in user }

      context 'admin set limited to public and no embargoes' do
        let(:admin_set) { Hyrax::AdminSetCreateService.find_or_create_default_admin_set }

        let!(:permission_template) do
          FactoryBot.create(:permission_template,
                            source_id: admin_set.id,
                            release_period: Hyrax::PermissionTemplate::RELEASE_TEXT_VALUE_NO_DELAY)
        end

        let!(:permission_template_access) do
          FactoryBot.create(:permission_template_access,
                      :deposit,
                      permission_template: permission_template,
                      agent_type: 'user',
                      agent_id: user.user_key)
        end

        let!(:workflow) do
          Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                                  permission_template_id: permission_template.id)
        end

        context 'as a regular user' do
          let(:user) { FactoryBot.create(:user) }

          it 'populates allowed admin sets with configured visibility restrictions' do
            admin_sets = controller.available_admin_sets
            options = admin_sets.select_options

            expect(options).to contain_exactly(
              ['Default Admin Set', admin_set.id.to_s, {'data-release-no-delay'=>true, 'data-sharing'=>true}])
          end
        end

        context 'as an admin user' do
          let(:user) { FactoryBot.create(:admin) }

          it 'populates allowed admin sets without visibility restrictions' do
            admin_sets = controller.available_admin_sets
            options = admin_sets.select_options

            expect(options).to contain_exactly(
              ['Default Admin Set', admin_set.id.to_s, {'data-sharing'=>true}])
          end
        end
      end
    end
  end
end
