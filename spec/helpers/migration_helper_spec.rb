# frozen_string_literal: true
require 'rails_helper'
require 'tasks/migration_helper'

RSpec.describe MigrationHelper do
  describe '#check_enumeration' do
    let(:metadata) do
      {
        'title' => 'a title for an article', # should be array
        'date_issued' => '2019-10-02', # should be string
        'edition' => ['preprint'], # should be string
        'alternative_title' => ['another title for an article'] # should be array
      }
    end
    let(:resource) { Article.new }
    let(:identifier) { 'my new article' }
    let(:formatted_metadata) do
      {
        'title' => ['a title for an article'],
        'date_issued' => '2019-10-02',
        'edition' => 'preprint',
        'alternative_title' => ['another title for an article'],
        'visibility' => 'open'
      }
    end

    it 'verifies enumeration of work type attributes' do
      article = described_class.check_enumeration(metadata, resource, identifier)
      article_attributes = article.attributes.delete_if { |_k, v| v.blank? } # remove nil values and empty arrays

      expect(article_attributes).to eq formatted_metadata
    end
  end
end
