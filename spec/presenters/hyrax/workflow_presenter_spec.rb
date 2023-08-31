# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::WorkflowPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:attributes) do
    { 'id' => '888888',
      'has_model_ssim' => ['GenericWork'] }
  end

  let(:user) do
    User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false) }
  end
  let(:ability) { Ability.new(user) }
  let(:presenter) { described_class.new(solr_document, ability) }
  let(:entity) { instance_double(Sipity::Entity) }

  let(:workflow) { FactoryBot.create(:workflow, name: 'testing') }

  describe "#actions" do
    subject { presenter.actions }

    context 'with a Sipity::Entity in pending_deletion state' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('pending_deletion')
        allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_permitted_workflow_actions_available_for_current_state).and_return([Sipity::WorkflowAction.new(name: "complete", workflow: workflow)])
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end

      context 'as non-admin' do
        it { is_expected.to eq [] }
      end

      context 'as admin' do
        let(:admin_user) { FactoryBot.create(:admin) }
        let(:ability) { Ability.new(admin_user) }

        it "user has normal actions" do
          allow(I18n).to receive(:t).with('hyrax.workflow.testing.complete', default: 'Complete').and_return("Approve")
          is_expected.to eq [['complete', 'Approve']]
        end
      end
    end
  end

  describe '#badge' do
    subject { presenter.badge }

    context 'with a Sipity::Entity marked as withdrawn' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('withdrawn')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to eq '<span class="state state-withdrawn badge badge-primary">Withdrawn</span>' }
    end
  end

  describe '#is_mfa_in_review?' do
    subject { presenter.is_mfa_in_review? }

    context 'with a Sipity::Entity marked as Pending Review and Art MFA Workflow' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('pending_review')
        allow(entity).to receive(:workflow_name).and_return('art_mfa_deposit')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be true }
    end

    context 'with a Sipity::Entity marked as Pending Review and Test Workflow' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('pending_review')
        allow(entity).to receive(:workflow_name).and_return('test_workflow')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be false }
    end

    context 'with a Sipity::Entity marked as Deposited and Art MFA Workflow' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('deposited')
        allow(entity).to receive(:workflow_name).and_return('art_mfa_deposit')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be false }
    end

    context 'with a Sipity::Entity marked as Deposited and Test Workflow' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('deposited')
        allow(entity).to receive(:workflow_name).and_return('test_workflow')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be false }
    end
  end

  describe 'is_mfa?' do
    subject { presenter.is_mfa? }

    context 'with a Sipity::Entity marked as Pending Review and Art MFA Workflow' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('pending_review')
        allow(entity).to receive(:workflow_name).and_return('art_mfa_deposit')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be true }
    end

    context 'with a Sipity::Entity marked as Deposited and Art MFA Workflow' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('deposited')
        allow(entity).to receive(:workflow_name).and_return('art_mfa_deposit')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be true }
    end

    context 'with a Sipity::Entity marked as Deposited and Test Workflow' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('deposited')
        allow(entity).to receive(:workflow_name).and_return('test_workflow')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be false }
    end
  end

  describe '#in_workflow_state?' do
    subject { presenter.in_workflow_state?(['withdrawn', 'pending deletion']) }

    context 'with a Sipity::Entity marked as Withdrawn' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('withdrawn')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be true }
    end

    context 'with a Sipity::Entity marked as Pending Deletion' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('pending deletion')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be true }
    end

    context 'with a Sipity::Entity marked as Deposited' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('deposited')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to be false }
    end
  end
end
