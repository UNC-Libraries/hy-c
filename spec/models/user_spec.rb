# frozen_string_literal: true
require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { User.new(email: 'test@example.com', guest: false, uid: 'someid') { |u| u.save!(validate: false) } }

  describe 'override hyrax info notice id transformation' do
    it 'does not change users ids from test@example.com to test@example-dot-com' do
      expect(user.email).to eq 'test@example.com'
    end
  end

  describe 'omniauthable user' do
    it 'has a uid field' do
      expect(user.uid).not_to be_empty
    end
    it 'can have a provider' do
      expect(described_class.new.respond_to?(:provider)).to eq true
    end

    context 'autocreate user passwords' do
      before do
        described_class.delete_all
      end
      it 'system users are created without error' do
        allow(AuthConfig).to receive(:use_database_auth?).and_return(false)
        u = ::User.find_or_create_system_user('batch_user')
        expect(u).to be_instance_of(::User)
      end
    end

    context 'shibboleth integration' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'shibboleth',
          uid: 'boxy',
          info: {
            display_name: 'boxy',
            uid: 'boxy',
            mail: 'boxy@example.com'
          }
        )
      end
      let(:user) { described_class.from_omniauth(auth_hash) }

      before do
        described_class.delete_all
      end

      context 'shibboleth' do
        it 'has a shibboleth provided name' do
          expect(user.display_name).to eq auth_hash.info.display_name
        end
        it 'has a shibboleth provided uid which is not nil' do
          expect(user.uid).to eq auth_hash.info.uid
          expect(user.uid).not_to eq nil
        end
        it 'has a shibboleth provided email which is not nil' do
          expect(user.email).to eq "#{auth_hash.info.uid}@ad.unc.edu"
          expect(user.email).not_to eq nil
        end
      end
    end

    context 'no email from shibboleth' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'shibboleth',
          uid: 'boxy',
          info: {
            display_name: 'boxy',
            uid: 'boxy',
            mail: nil
          }
        )
      end
      let(:user) { described_class.from_omniauth(auth_hash) }

      before do
        described_class.delete_all
      end

      context 'shibboleth' do
        it 'has a shibboleth provided name' do
          expect(user.display_name).to eq auth_hash.info.display_name
        end
        it 'has a shibboleth provided uid which is not nil' do
          expect(user.uid).to eq auth_hash.info.uid
          expect(user.uid).not_to eq nil
        end
        it 'has a shibboleth provided email which is not nil' do
          expect(user.email).to eq "#{auth_hash.info.uid}@ad.unc.edu"
          expect(user.email).not_to eq nil
        end
      end
    end
  end
end
