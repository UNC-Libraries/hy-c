require 'rails_helper'

RSpec.describe Hyrax::StatsUsagePresenter do

  describe '#created' do
    let(:subject) {described_class.new}

    context 'for a migrated work' do
      article = Article.new(title: ['new article'], date_created: DateTime.yesterday)
      it 'sets google analytics query start date to original date created' do
        allow(subject).to receive(:model).and_return(article)

        expect(article.date_created).not_to eq article.create_date
        expect(subject.created).to eq article.date_created
      end
    end

    context 'for a non-migrated work' do
      article = Article.new(title: ['new article'])
      it 'sets google analytics query start date to ingest date' do
        allow(subject).to receive(:model).and_return(article)

        expect(article.date_created).to be_nil
        expect(subject.created).to eq article.create_date
      end
    end
  end
end
