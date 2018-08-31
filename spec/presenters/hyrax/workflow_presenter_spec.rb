require 'rails_helper'

RSpec.describe Hyrax::WorkflowPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:attributes) do
    { "id" => '888888',
      "has_model_ssim" => ["GenericWork"] }
  end

  let(:user) do
    User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
  end
  let(:ability) { Ability.new(user) }
  let(:presenter) { described_class.new(solr_document, ability) }
  let(:entity) { instance_double(Sipity::Entity) }

  describe "#badge" do
    let(:workflow) { create(:workflow, name: 'testing') }

    subject { presenter.badge }

    context 'with a Sipity::Entity marked as Tombstoned' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('tombstoned')
        allow(presenter).to receive(:sipity_entity).and_return(entity)
      end
      it { is_expected.to eq '<span class="state state-withdrawn label label-primary">Withdrawn</span>' }
    end
  end

  describe "#in_workflow_state?" do
    let(:workflow) { create(:workflow, name: 'testing') }

    subject { presenter.in_workflow_state?(['withdrawn', 'pending deletion']) }

    context 'with a Sipity::Entity marked as Tombstoned' do
      before do
        allow(entity).to receive(:workflow_state_name).and_return('tombstoned')
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