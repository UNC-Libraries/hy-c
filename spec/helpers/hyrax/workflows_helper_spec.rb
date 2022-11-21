# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Hyrax::WorkflowsHelper do
  describe '#workflow_restriction?' do
    let(:ability) { double }
    before { allow(controller).to receive(:current_ability).and_return(ability) }
    subject { helper.workflow_restriction?(object) }
    let(:workflow) { double(actions: returning_actions) }
    let(:object) { double(workflow: workflow) }

    context 'with read permissions' do
      before do
        allow(ability).to receive(:can?).with(:edit, object).and_return(false)
        allow(ability).to receive(:can?).with(:read, object).and_return(true)
      end

      context 'with no workflow actions' do
        let(:returning_actions) { [] }
        context 'object is suppressed' do
          before do
            allow(object).to receive(:suppressed?).and_return(true)
          end
          it { is_expected.to be_truthy }
        end
        context 'object is not suppressed' do
          before do
            allow(object).to receive(:suppressed?).and_return(false)
          end
          it { is_expected.to be_falsey }
        end
      end

      context 'with comment workflow action' do
        let(:returning_actions) { ['comment_only'] }
        it { is_expected.to be_falsey }
      end
    end
  end
end
