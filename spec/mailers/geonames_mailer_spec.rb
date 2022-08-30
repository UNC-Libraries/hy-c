require 'rails_helper'

RSpec.describe GeonamesMailer , type: :mailer do
  let(:mail) { described_class.send_mail(Exception.new('bad geonames request')) }

  it 'renders the headers' do
    expect(mail.subject).to eq('Unable to index geonames uri to human readable text')
    expect(mail.to).to eq([ENV['EMAIL_GEONAMES_ERRORS_ADDRESS']])
  end

  it 'renders the body' do
    expect(mail.body).to eq('bad geonames request')
  end
end
