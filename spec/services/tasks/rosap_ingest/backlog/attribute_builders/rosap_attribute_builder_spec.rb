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
  subject(:builder) { described_class.new(config: config, depositor: depositor, article: article) }

  describe '#apply_additional_basic_attributes' do
    let(:metadata) do
      {
            'title' => 'Sample ROSAP Article',
            'abstract' => 'This is a sample abstract for a ROSAP article.',
            'rosap_id' => 'R123456',
            'publisher' => 'Sample Publisher',
            'publication_year' => '2024',
            'keywords' => ['Science', 'Technology'],
            'creators' => [
                'Brown, Alice',
                'Johnson, Bob'
            ],
            'issn' => ['ISSN-9876-5432'],
        }
    end

    it 'assigns core article attributes from metadata' do
      builder.send(:apply_additional_basic_attributes, article, metadata)

      expect(article.title).to eq(['Sample ROSAP Article'])
      expect(article.abstract).to eq(['This is a sample abstract for a ROSAP article.'])
      expect(article.date_issued).to eq(['2024-01-01'])
      expect(article.creators).to eq([
                                        { 'name' => 'Brown, Alice', 'index' => '0' },
                                        { 'name' => 'Johnson, Bob', 'index' => '1' }
                                    ])
      expect(article.keywords).to eq(['Science', 'Technology'])
      expect(article.publisher).to eq(['Sample Publisher'])
    end
  end
end
