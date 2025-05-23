# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DecodeQueryString do
  describe '#call' do
    let(:app) { double('app') }

    before do
      allow(app).to receive(:call).and_return({})
    end

    context 'query string with encoded equal sign' do
      let(:env) { { 'QUERY_STRING' => 'f%5Bkeyword_sim%5D%5B%5D%3DPharmacogenetics&locale=en' } }
      let(:decoded_env) { { 'QUERY_STRING' => 'f%5Bkeyword_sim%5D%5B%5D=Pharmacogenetics&locale=en' } }

      it 'decodes the %3D character in the query string' do
        middleware = DecodeQueryString.new(app)
        middleware.call(env)

        expect(app).to have_received(:call).with(decoded_env)
      end
    end

    context 'query string with encoded equal in middle of param' do
      let(:env) { { 'QUERY_STRING' => 'f%5Bkeyword_sim%5D%5B%5D=Pharmacoge%3Dnetics&locale=en' } }
      let(:decoded_env) { { 'QUERY_STRING' => 'f%5Bkeyword_sim%5D%5B%5D=Pharmacoge%3Dnetics&locale=en' } }

      it 'leaves query string unchanged' do
        middleware = DecodeQueryString.new(app)
        middleware.call(env)

        expect(app).to have_received(:call).with(decoded_env)
      end
    end


    context 'query string with decoded equal sign' do
      let(:env) { { 'QUERY_STRING' => 'f%5Bkeyword_sim%5D%5B%5D=Pharmaco=genetics&locale=en' } }
      let(:decoded_env) { { 'QUERY_STRING' => 'f%5Bkeyword_sim%5D%5B%5D=Pharmaco=genetics&locale=en' } }

      it 'leaves query string unchanged' do
        middleware = DecodeQueryString.new(app)
        middleware.call(env)

        expect(app).to have_received(:call).with(decoded_env)
      end
    end

    context 'when an exception occurs' do
      let(:env) { { 'QUERY_STRING' => 'f%5Bkeyword_sim%5D%5B%5D=Pharmacogenetics&locale=en' } }
      let(:error) { StandardError.new('Test error') }

      before do
        allow(app).to receive(:call).and_raise(error)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the exception and backtrace, then re-raises it' do
        middleware = DecodeQueryString.new(app)

        expect { middleware.call(env) }.to raise_error(StandardError)
        expect(Rails.logger).to have_received(:error).with('StandardError: Test error')
        expect(Rails.logger).to have_received(:error).with(error.backtrace.join("\n"))
      end
    end
  end
end
