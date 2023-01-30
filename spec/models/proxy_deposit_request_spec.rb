# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ProxyDepositRequest, type: :model do
  include ActionView::Helpers::UrlHelper

  let(:sender) { FactoryBot.create(:user) }
  let(:receiver) { FactoryBot.create(:user) }
  let(:receiver2) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:admin) }
  let(:work_id) { '123abc' }
  let(:stubbed_work_query_service_class) { double(new: work_query_service) }
  let(:work_query_service) { double(work: work) }
  let(:work) { General.new(title: ['Test Work']) }

  subject do
    described_class.new(work_id: work_id, sending_user: sender,
                        receiving_user: receiver, sender_comment: 'please take this')
  end

  # Injecting a different work_query_service_class to avoid hitting SOLR and Fedora
  before do
    @original_work_query_service_class = described_class.work_query_service_class
    described_class.work_query_service_class = stubbed_work_query_service_class
    allow(work).to receive(:id).and_return(work_id)
  end

  after do
    described_class.work_query_service_class = @original_work_query_service_class
  end

  describe 'transfer' do
    context 'when the transfer_to user is found' do
      it 'creates a transfer_request' do
        subject.transfer_to = receiver.user_key
        expect { subject.save! }.to change { receiver.mailbox.inbox(unread: true).count }.from(0).to(1)
        expect(receiver.mailbox.inbox.last.last_message.subject).to eq 'CDR work transfer request'
        user_link = link_to(sender.name, Hyrax::Engine.routes.url_helpers.user_path(sender))
        transfer_link = link_to('transfer requests', Hyrax::Engine.routes.url_helpers.transfers_path)
        work_link = link_to work.title.first, "#{ENV['HYRAX_HOST']}/concern/#{work.class.to_s.underscore}s/#{work.id}"
        expect(receiver.mailbox.inbox.last.last_message.body).to include(user_link + ' wants to transfer ownership of ' + work_link + ' to you. To accept this transfer request, go to the Carolina Digital Repository (CDR) ' + transfer_link)
        proxy_request = receiver.proxy_deposit_requests.first
        expect(proxy_request.work_id).to eq(work_id)
        expect(proxy_request.sending_user).to eq(sender)
      end

      context 'with receiver comment' do
        subject do
          described_class.new(work_id: work_id, sending_user: sender,
                              receiving_user: receiver, sender_comment: 'please take this', receiver_comment: 'ok')
        end

        it 'updates a transfer_request' do
          subject.transfer_to = receiver.user_key
          expect { subject.save! }.to change { receiver.mailbox.inbox(unread: true).count }.from(0).to(1)
          subject.status = described_class::ACCEPTED
          subject.save!
          work_link = link_to work.title.first, "#{ENV['HYRAX_HOST']}/concern/#{work.class.to_s.underscore}s/#{work.id}"
          expect(sender.mailbox.inbox.last.last_message.subject).to eq 'CDR work transfer request accepted'
          expect(sender.mailbox.inbox.last.last_message.body).to include('Your request to transfer request ownership of ' + work_link + ' has been ' + described_class::ACCEPTED + ' by ' + receiver.email)
        end
      end
    end
  end
end
