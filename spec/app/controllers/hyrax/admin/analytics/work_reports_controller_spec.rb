# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/analytics'

RSpec.describe Hyrax::Admin::Analytics::WorkReportsController, type: :controller do
  routes { Hyrax::Engine.routes }
  describe 'GET #index' do
    around do |example|
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      original_analytics = Hyrax.config.analytics?
      original_provider = Hyrax.config.analytics_provider
      original_start_date = Hyrax.config.analytics_start_date
      Hyrax.config.analytics_start_date = '2018-01-01'
      Hyrax.config.analytics = true
      Hyrax.config.analytics_provider = 'matomo'
      example.run
      Hyrax.config.analytics = original_analytics
      Hyrax.config.analytics_provider = original_provider
      Hyrax.config.analytics_start_date = original_start_date
    end

    context 'when user is not logged in' do
      it 'redirects to the login page' do
        get :index
        expect(response).to be_redirect
        expect(flash[:alert]).to eq('You need to sign in or sign up before continuing.')
      end
    end

    context 'when user is logged in' do
      let(:admin_user) { FactoryBot.create(:admin) }
      let(:work) { FactoryBot.create(:work_with_files, user: admin_user) }

      before do
        sign_in admin_user
        allow(Time.zone).to receive(:today).and_return(Date.new(2019, 10, 20))
      end

      it 'returns a success response' do
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
        spec_fileset_ids = work.members.map(&:id)

        generate_hyc_stats_for_range(work.id, spec_fileset_ids[0], spec_downloads)
        generate_hyc_stats_for_range(work.id, spec_fileset_ids[1], spec_downloads)

        expect(Hyrax::Analytics).to receive(:api_params).with('Events.getAction', 'month', '2018-01-01,2019-10-20',
            { label: 'work-view'}).and_return(spec_page_views_hash)

        total_views = spec_page_views.map { |pair| pair[1] }.sum
        spec_top_events_page_views = [{
          'label' => "#{work.id} - work-view",
          'nb_visits' => 3,
          'nb_events' => total_views,
          'nb_events_with_value' => 0,
          'sum_event_value' => 0,
          'min_event_value' => false,
          'max_event_value' => false,
          'sum_daily_nb_uniq_visitors' => 0,
          'avg_event_value' => 0,
          'Events_EventName' => work.id,
          'Events_EventAction' => 'work-view'
        }]
        expect(Hyrax::Analytics).to receive(:api_params).with('Events.getName', 'range', '2018-01-01,2019-10-21', {
              filter_column: 'Events_EventAction',
              filter_limit: '-1',
              filter_pattern: 'work-view',
              filter_sort_column: 'nb_events',
              filter_sort_order: 'desc',
              flat: '1'}).and_return(spec_top_events_page_views)

        get :index
        expect(response).to be_successful
        works_count = subject.instance_variable_get('@works_count')
        expect(works_count).to eq(1)
        pageviews = subject.instance_variable_get('@pageviews')
        expect(pageviews.results).to include(expected_page_views[0], expected_page_views[1], expected_page_views[2])
        downloads = subject.instance_variable_get('@downloads')
        expect(downloads.results).to include(expected_downloads[0], expected_downloads[1], expected_downloads[2])
        # The test file sets don't have titles, so they won't be included in the top list
        top_file_set_downloads = subject.instance_variable_get('@top_file_set_downloads')
        expect(top_file_set_downloads).to eq([])
        top_works = subject.instance_variable_get('@top_works')
        expect(top_works.count).to eq(1)
      end
    end
  end

  def generate_hyc_stats_for_range(work_id, fileset_id, expected_downloads)
    expected_downloads.each do |pair|
      event_date = "#{pair[0]}-01"
      FactoryBot.create(:hyc_download_stat, work_id: work_id, fileset_id: fileset_id, date: event_date, download_count: pair[1])
    end
  end
end
