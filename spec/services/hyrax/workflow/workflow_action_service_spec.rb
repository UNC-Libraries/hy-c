# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Workflow::WorkflowActionService do
  let(:workflow_subject) { double }
  let(:action) { 'approve' }
  let(:comment) { 'I approve' }
  let(:work) { double }
  let(:service) { Hyrax::Workflow::WorkflowActionService.new(subject: workflow_subject, action: action, comment: comment) }

  before do
    allow(workflow_subject).to receive(:work).and_return(work)
    allow(work).to receive(:id).and_return('99')
    allow(workflow_subject).to receive(:user).and_return('user')
    allow(service).to receive(:update_sipity_workflow_state)
    allow(service).to receive(:create_sipity_comment)
    allow(service).to receive(:handle_sipity_notifications)
    allow(work).to receive(:update_index)
  end

  describe '#run' do
    context 'additional actions fail with mismatch error every time' do
      before do
        allow(Hyrax::Workflow::ActionTakenService).to receive(:handle_action_taken).and_raise(ActiveFedora::ModelMismatch)
      end

      it 'retries and eventually raises error' do
        expect { service.run }.to raise_error(ActiveFedora::ModelMismatch)
        expect(Hyrax::Workflow::ActionTakenService).to have_received(:handle_action_taken).exactly(3).times
      end
    end

    context 'additional actions succeeds' do
      before do
        allow(Hyrax::Workflow::ActionTakenService).to receive(:handle_action_taken)
      end

      it 'executes once and returns' do
        service.run

        expect(Hyrax::Workflow::ActionTakenService).to have_received(:handle_action_taken).exactly(1).times
      end
    end
  end
end
