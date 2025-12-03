# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::RosapIngest::Backlog::Utilities::AttributeBuilders::RosapAttributeBuilder do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:article) { FactoryBot.build(:article) }
  let(:config) do
    {
        'admin_set_title' => admin_set.title,
        'depositor_onyen' => depositor.uid,
        'output_dir' => '/tmp/rosap_output',
        'full_text_dir' => '/tmp/rosap_full_text'
    }
  end
  let(:metadata) do
    {
           'title' => 'Sample ROSAP Article',
           'abstract' => 'This is a sample abstract for a ROSAP article.',
           'rosap_id' => 'R123456',
           'publisher' => 'Sample Publisher',
           'date_issued' => '2024-01-01',
           'keywords' => ['Science', 'Technology'],
           'authors' => [
               'Brown, Alice',
               'Johnson, Bob'
           ],
       }
  end
  subject(:builder) { described_class.new(metadata, admin_set, depositor.uid) }

  describe '#apply_additional_basic_attributes' do
    it 'assigns core article attributes from metadata' do
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.title).to eq(['Sample ROSAP Article'])
      expect(article.abstract).to eq(['This is a sample abstract for a ROSAP article.'])
      expect(article.date_issued).to eq('2024-01-01')
      expect(article.keyword).to eq(['Science', 'Technology'])
      expect(article.publisher).to eq(['Sample Publisher'])
    end
  end

  describe '#set_identifiers' do
    it 'sets the identifier attribute with ROSAP ID' do
      builder.send(:set_identifiers, article)

      expect(article.identifier).to eq(['ROSA-P ID: R123456'])
    end
  end

  describe '#generate_authors' do
    it 'returns an array of author names from metadata' do
      authors = builder.send(:generate_authors)
      expect(authors).to eq(['Brown, Alice', 'Johnson, Bob'])
    end
  end
end
