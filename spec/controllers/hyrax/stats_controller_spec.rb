# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/analytics'
RSpec.describe Hyrax::StatsController do
  let(:user) { FactoryBot.create(:user) }
  let(:usage) { double }
  let(:document) { instance_double(SolrDocument) }

  before do
    sign_in user
    request.env['HTTP_REFERER'] = 'http://test.host/foo'
    allow_any_instance_of(User).to receive(:groups).and_return([])
  end

  routes { Hyrax::Engine.routes }

  describe 'work' do
    let(:work) { FactoryBot.create(:work_with_files, user: user) }

    before do
      allow(Time.zone).to receive(:today).and_return(Date.new(2019, 10, 20))
    end

    it 'renders the stats view' do
      dates = [Date.new(2019, 6, 1), Date.new(2019, 7, 1), Date.new(2019, 8, 1)]
      formatted_dates = dates.map { |time| time.strftime('%Y-%m') }
      spec_page_views = formatted_dates.map { |date| [date, rand(11)] }
      expected_page_views = dates.each_with_index.map { |date, i| [date, spec_page_views[i][1]] }
      spec_page_views_hash = Hash.new
      spec_page_views.each_with_object(spec_page_views_hash) do |pair, hash|
        hash[pair[0]] = [{'nb_events' => pair[1]}]
      end
      spec_downloads = formatted_dates.map { |date| [date, rand(11)] }
      # Expected downloads need to be doubled since there are two filesets with the same stats
      expected_downloads = dates.each_with_index.map { |date, i| [date, spec_downloads[i][1] * 2] }
      spec_downloads_hash = Hash.new
      spec_downloads.each_with_object(spec_downloads_hash) do |pair, hash|
        hash[pair[0]] = [{'nb_events' => pair[1]}]
      end
      spec_fileset_ids = work.members.map(&:id)

      generate_hyc_stats_for_range(work.id, spec_fileset_ids[0], spec_downloads)
      generate_hyc_stats_for_range(work.id, spec_fileset_ids[1], spec_downloads)

      expect(Hyrax::Analytics).to receive(:api_params).with('Events.getName', 'month', anything, { flat: 1,
            label: "#{work.id} - work-view"}).and_return(spec_page_views_hash)
      expect(controller).to receive(:add_breadcrumb).with('Home', Hyrax::Engine.routes.url_helpers.root_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.my.works'), Hyrax::Engine.routes.url_helpers.my_works_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.title'), Hyrax::Engine.routes.url_helpers.dashboard_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with('Test title', "/concern/generals/#{work.id}?locale=en")
      get :work, params: { id: work.id }
      expect(response).to be_successful
      pageviews = subject.instance_variable_get('@pageviews')
      downloads = subject.instance_variable_get('@downloads')

      expect(pageviews.results).to eq(expected_page_views)
      expect(downloads.results.count).to eq 12
      expected_downloads.each do |pair|
        expect(downloads.results).to include(pair)
      end
      # Expect blank entries for missing months
      expect(downloads.results).to include([Date.new(2018, 11, 1), 0])
      expect(downloads.results).to include([Date.new(2018, 12, 1), 0])
      expect(downloads.results).to include([Date.new(2019, 1, 1), 0])
      expect(downloads.results).to include([Date.new(2019, 2, 1), 0])
      expect(downloads.results).to include([Date.new(2019, 3, 1), 0])
      expect(downloads.results).to include([Date.new(2019, 4, 1), 0])
      expect(downloads.results).to include([Date.new(2019, 5, 1), 0])
      expect(downloads.results).to include([Date.new(2019, 9, 1), 0])
      expect(downloads.results).to include([Date.new(2019, 10, 1), 0])
    end
  end

  def generate_hyc_stats_for_range(work_id, fileset_id, expected_downloads)
    expected_downloads.each do |pair|
      event_date = "#{pair[0]}-01"
      FactoryBot.create(:hyc_download_stat, work_id: work_id, fileset_id: fileset_id, date: event_date, download_count: pair[1])
    end
  end

  describe 'file' do
    it 'raises a routing error' do
      get :file, params: { id: '123' }
      expect(response).to be_not_found
    end
  end
end
