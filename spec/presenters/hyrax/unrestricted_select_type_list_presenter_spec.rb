# frozen_string_literal: true
require 'rails_helper'
# Note: test app generates multiple work types (concerns) now
RSpec.describe Hyrax::UnrestrictedSelectTypeListPresenter do
  let(:instance) { described_class.new(user) }
  let(:user) { nil }

  describe '#many?' do
    subject { instance.many? }

    context 'without a logged in user' do
      it { is_expected.to be true }

      context 'if user is nil' do
        it { is_expected.to be true }
      end
    end

    context 'with a logged in user' do
      let(:user) do
        User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false) }
      end

      it { is_expected.to be true }
      context 'if authorized_models returns only one' do
        before do
          allow(instance).to receive(:authorized_models).and_return([double])
        end
        it { is_expected.to be false }
      end
    end
  end
end
