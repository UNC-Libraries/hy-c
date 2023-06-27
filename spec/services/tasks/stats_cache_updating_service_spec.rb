# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::StatsCacheUpdatingService do  
  describe '#update_all' do
    let(:general) do
      General.create(title: ['new general'],
                    date_created: (Time.zone.today - 40.days).to_s)
    end
    let(:file_set_1) { FactoryBot.create(:file_set, :with_original_file,
                                         date_created: (Time.zone.today - 40.days).to_s)}
    let(:file_set_2) { FactoryBot.create(:file_set, :with_original_file,
                                         date_created: (Time.zone.today - 39.days).to_s)}
    
    let(:article) do
        Article.create(title: ['new article'],
                    date_issued: 'May 2020',
                    date_created: (Time.zone.today - 30.days).to_s,
                    resource_type: ['Article'],
                    abstract: ['a description'],
                    language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                    rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/')
    end

    let(:dates) do
      ldates = []
      4.downto(0) { |idx| ldates << (Time.zone.today - idx.day) }
      ldates
    end
    let(:date_strs) do
      dates.map { |date| date.strftime("%Y%m%d") }
    end

    let(:sample_work_pageview_statistics) do
      [
        SpecStatistic.new(date: date_strs[0], pageviews: 4),
        SpecStatistic.new(date: date_strs[1], pageviews: 8),
        SpecStatistic.new(date: date_strs[2], pageviews: 6),
        SpecStatistic.new(date: date_strs[3], pageviews: 10)
      ]
    end

    let(:file_download_statistics) do
      [
        SpecStatistic.new(eventCategory: "Files", eventAction: "Downloaded", eventLabel: "hyrax:x920fw85p", date: date_strs[0], totalEvents: "1"),
        SpecStatistic.new(eventCategory: "Files", eventAction: "Downloaded", eventLabel: "hyrax:x920fw85p", date: date_strs[1], totalEvents: "1"),
        SpecStatistic.new(eventCategory: "Files", eventAction: "Downloaded", eventLabel: "hyrax:x920fw85p", date: date_strs[3], totalEvents: "3")
      ]
    end

    let(:file_pageview_statistics) do
      [
        SpecStatistic.new(date: date_strs[2], pageviews: 6),
        SpecStatistic.new(date: date_strs[3], pageviews: 10)
      ]
    end

    before do
      allow(Hyrax.config).to receive(:analytic_start_date).and_return('2020-01-01T12:01:01Z')
      allow(WorkViewStat).to receive(:ga_statistics).and_return(sample_work_pageview_statistics)
      allow(FileDownloadStat).to receive(:ga_statistics).and_return(file_download_statistics)
      allow(FileViewStat).to receive(:ga_statistics).and_return(file_pageview_statistics)

      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit

      general.members << file_set_1
      general.members << file_set_2
    end

    it 'Updates the cache for both works and files' do
      general
      article

      subject.per_page = 1
      
      subject.update_all
      # verify that cache tables are populated
      cached_for_article = WorkViewStat.statistics_for(article).to_a
      expect(cached_for_article.length).to eq 4
      cached_for_general = WorkViewStat.statistics_for(general).to_a
      expect(cached_for_general.length).to eq 4
      cached_for_fs1_views = FileViewStat.statistics_for(file_set_1).to_a
      expect(cached_for_fs1_views.length).to eq 2
      cached_for_fs1_downloads = FileDownloadStat.statistics_for(file_set_1).to_a
      expect(cached_for_fs1_downloads.length).to eq 3
      cached_for_fs2_views = FileViewStat.statistics_for(file_set_2).to_a
      expect(cached_for_fs2_views.length).to eq 2
      cached_for_fs2_downloads = FileDownloadStat.statistics_for(file_set_2).to_a
      expect(cached_for_fs2_downloads.length).to eq 3
    end
  end

  class SpecStatistic
    def initialize(**kargs)
      @attributes = kargs.symbolize_keys
    end

    def [](key)
      @attributes[key.to_sym]
    end

    def method_missing(method_name, *arguments, &block)
      if @attributes.key?(method_name.to_sym)
        @attributes[method_name]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @attributes.key?(method_name.to_sym) || super
    end
  end
end