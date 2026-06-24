# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::SharedUtilities::PmcS3VersionLookup do
  subject(:lookup) { lookup_class.new }

  let(:lookup_class) do
    Class.new do
      include Tasks::PubmedIngest::SharedUtilities::PmcS3VersionLookup
    end
  end

  describe '#latest_version_prefix' do
    let(:list_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
          <CommonPrefixes><Prefix>PMC123456.1/</Prefix></CommonPrefixes>
          <CommonPrefixes><Prefix>PMC123456.2/</Prefix></CommonPrefixes>
        </ListBucketResult>
      XML
    end

    before do
      allow(HTTParty).to receive(:get)
                           .with(a_string_including('PMC123456.'), timeout: 10)
                           .and_return(double('response', code: 200, body: list_xml))
    end

    it 'returns the latest (sorted) version prefix' do
      expect(lookup.latest_version_prefix('PMC123456')).to eq('PMC123456.2/')
    end

    context 'when no versions exist' do
      let(:empty_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
          </ListBucketResult>
        XML
      end

      before do
        allow(HTTParty).to receive(:get)
                             .with(a_string_including('PMC123456.'), timeout: 10)
                             .and_return(double('response', code: 200, body: empty_xml))
      end

      it 'returns nil' do
        expect(lookup.latest_version_prefix('PMC123456')).to be_nil
      end
    end

    context 'when the S3 listing request fails' do
      before do
        allow(HTTParty).to receive(:get)
                             .with(a_string_including('PMC123456.'), timeout: 10)
                             .and_return(double('response', code: 500, body: ''))
      end

      it 'raises an error' do
        expect { lookup.latest_version_prefix('PMC123456') }.to raise_error(/S3 listing failed/)
      end
    end
  end
end
