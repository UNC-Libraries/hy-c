require 'rails_helper'

RSpec.describe Tasks::EmbargoExpirationService do
  let(:article) { Article.new(title: ['new article with embargo'],
                              embargo_release_date: Date.today+1.day, # cannot create embargoes in the past
                              visibility_during_embargo: 'restricted',
                              visibility_after_embargo: 'open') }

  describe '#run' do
    before do
      article.save!
    end

    context 'without a date' do
      it 'expires embargoes through today' do
        Tasks::EmbargoExpirationService.run(nil)
        article.reload
        expect(article.visibility).to eq 'restricted' # does not expire future embargo
      end
    end

    context 'with a date' do
      it 'expires embargoes through the given date' do
        Tasks::EmbargoExpirationService.run((Date.today+2.days).to_s)
        article.reload
        expect(article.visibility).to eq 'open'
      end
    end
  end

  describe '#solrize_date' do
    it 'formats dates for solr' do
      service = Tasks::EmbargoExpirationService.new(nil).solrize_date(Date.parse('Nov 12, 2019'))
      expect(service).to eq '2019-11-12T00:00:00Z'
    end
  end

  describe '#initialize' do
    context 'without a date' do
      it 'sets all params' do
        service = Tasks::EmbargoExpirationService.new(nil)
        expect(service.date).to be_nil
        expect(service.work_types).to match_array [Article, Artwork, DataSet, Dissertation, General, HonorsThesis, Journal, MastersPaper, Multimed, ScholarlyWork]
      end
    end

    context 'with a date' do
      it 'sets all params' do
        service = Tasks::EmbargoExpirationService.new(Date.today)
        expect(service.date).to eq Date.today
        expect(service.work_types).to match_array [Article, Artwork, DataSet, Dissertation, General, HonorsThesis, Journal, MastersPaper, Multimed, ScholarlyWork]
      end
    end
  end

  describe '#exipre_embargoes' do
    before do
      article.save!
    end

    it 'expires embargoes' do
      Tasks::EmbargoExpirationService.new(Date.today+2.days).expire_embargoes
      article.reload
      expect(article.visibility).to eq 'open'
    end
  end

  describe '#find_expirations' do
    before do
      article.save!
    end

    it 'finds works wtih embargoes that are expired' do
      service = Tasks::EmbargoExpirationService.new(Date.today+2.days).find_expirations
      expect(service).to match_array [article]
    end
  end
end
