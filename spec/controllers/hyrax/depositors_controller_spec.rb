require 'rails_helper'

# test overridden action
RSpec.describe Hyrax::DepositorsController, type: :request do
  let(:user) do
    User.new(email: "test#{Date.today.to_time.to_i}@example.com", guest: false, uid: "test#{Date.today.to_time.to_i}") { |u| u.save!(validate: false)}
  end

  let(:grantee) do
    User.new(email: 'grantee@example.com', guest: false, uid: 'grantee') { |u| u.save!(validate: false)}
  end

  let(:grant_proxy_params) do
    {
        user_id: user.user_key,
        grantee_id: grantee.user_key,
        format: 'json'
    }
  end

  let(:revoke_proxy_params) do
    {
        user_id: user.user_key,
        id: grantee.user_key,
        format: 'json'
    }
  end

  context "as a logged in user" do
    before do
      sign_in user
    end

    describe "#create" do
      context 'when the grantee has not yet been designated as a depositor' do
        let(:request_to_grant_proxy) { post hyrax.user_depositors_path(grant_proxy_params) }

        it 'is successful' do
          expect { request_to_grant_proxy }.to change { ProxyDepositRights.count }.by(1)
          expect(response).to be_success
        end

        it 'sends a message to the grantor' do
          expect { request_to_grant_proxy }.to change { user.mailbox.inbox.count }.by(1)
          expect(user.mailbox.inbox.last.last_message.subject).to eq I18n.t('hyrax.notifications.proxy_depositor_added.subject')
          expect(user.mailbox.inbox.last.last_message.body).to eq I18n.t('hyrax.notifications.proxy_depositor_added.grantor_message', grantee: grantee.name)
        end

        it 'sends a message to the grantee' do
          expect { request_to_grant_proxy }.to change { grantee.mailbox.inbox.count }.by(1)
          expect(grantee.mailbox.inbox.last.last_message.subject).to eq I18n.t('hyrax.notifications.proxy_depositor_added.subject')
          expect(grantee.mailbox.inbox.last.last_message.body).to eq I18n.t('hyrax.notifications.proxy_depositor_added.grantee_message', grantor: user.name)
        end
      end

      context 'when the grantee is already an allowed depositor' do
        # For this test we just set the grantor to be eq to grantee.
        let(:redundant_request_to_grant_proxy) do
          post hyrax.user_depositors_path(grant_proxy_params.merge(grantee_id: user.user_key))
        end

        it 'does not add the user, and returns a 200, with empty response body' do
          expect { redundant_request_to_grant_proxy }.to change { ProxyDepositRights.count }.by(0)
          expect(response).to be_success
          expect(response.body).to be_blank
        end

        it 'does not send a message to the user' do
          expect { redundant_request_to_grant_proxy }.not_to change { user.mailbox.inbox.count }
        end
      end
    end
  end
end
