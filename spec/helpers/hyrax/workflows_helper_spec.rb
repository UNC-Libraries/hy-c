# frozen_string_literal: true
RSpec.describe Hyrax::WorkflowsHelper do
  describe '#workflow_restriction?' do
    let(:ability) { double }
    before { allow(controller).to receive(:current_ability).and_return(ability) }
    subject { helper.workflow_restriction?(object) }
    let(:workflow) { double(actions: returning_actions) }
    let(:object) { double(workflow: workflow) }

    context 'with read permissions' do
      before { expect(ability).to receive(:can?).with(:read, object).and_return(true) }

      context 'with no workflow actions' do
        let(:returning_actions) { [] }
        it { is_expected.to be_truthy }
      end

      context 'with comment workflow action' do
        let(:returning_actions) { ['comment_only'] }
        it { is_expected.to be_falsey }
      end
    end
  end
end
