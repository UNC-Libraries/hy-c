# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::WorksControllerBehavior, type: :controller do
  let(:paths) { controller.main_app }

  controller(ApplicationController) do
    include Hyrax::WorksControllerBehavior # rubocop:disable RSpec/DescribedClass

    self.curation_concern_type = General
  end

  before do
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
  end

  describe '#available_admin_sets' do
    context 'with a logged in user' do
      before { sign_in user }

      context 'admin set limited to public and no embargoes' do
        let(:admin_set) do
          AdminSet.create(title: ['test admin set'],
                          edit_users: [user.user_key])
        end
        let(:permission_template) do
          Hyrax::PermissionTemplate.create!(source_id: admin_set.id,
                                            release_period: Hyrax::PermissionTemplate::RELEASE_TEXT_VALUE_NO_DELAY)
        end
        let(:workflow) { Sipity::Workflow.find_by!(name: 'default', permission_template: permission_template) }

        before do
          Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: user.user_key,
                                             access: 'deposit')
        end

        context 'as a regular user' do
          let(:user) { FactoryBot.create(:user) }

          it 'populates allowed admin sets with configured visibility restrictions' do
            admin_sets = controller.available_admin_sets
            options = admin_sets.select_options

            expect(options).to contain_exactly(
              ['test admin set', admin_set.id.to_s, {'data-release-no-delay'=>true, 'data-sharing'=>false}])
          end
        end

        context 'as an admin user' do
          let(:user) { FactoryBot.create(:admin) }

          it 'populates allowed admin sets without visibility restrictions' do
            admin_sets = controller.available_admin_sets
            options = admin_sets.select_options

            expect(options).to contain_exactly(
              ['test admin set', admin_set.id.to_s, {'data-sharing'=>true}])
          end
        end
      end
    end
  end

  describe '#permissions_changed?' do
    let(:user) { FactoryBot.create(:user) }
    let(:work) {
        General.new(title: ['test work'])
      }

    context 'with no new permissions or embargo' do
      it 'returns false' do
        allow(work).to receive(:under_embargo?).and_return(false)
        controller.instance_variable_set(:@curation_concern, work)

        controller.send(:save_permissions)

        expect(controller.send(:permissions_changed?)).to be false
      end
    end

    context 'with an embargo added' do
      it 'returns true' do
        allow(work).to receive(:under_embargo?).and_return(true)
        controller.instance_variable_set(:@curation_concern, work)

        controller.send(:save_permissions)

        expect(controller.send(:permissions_changed?)).to be true
      end
    end

    context 'with new permissions but no new embargo' do
      it 'returns true' do
        allow(work).to receive(:under_embargo?).and_return(false)
        allow(controller).to receive(:original_permissions_changed?).and_return(true)
        controller.instance_variable_set(:@curation_concern, work)

        controller.send(:save_permissions)

        expect(controller.send(:permissions_changed?)).to be true
      end
    end
  end
end
