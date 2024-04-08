# frozen_string_literal: true
require 'rails_helper'
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

    it 'renders the stats view' do
      dates = [Time.new(2019, 6, 19), Time.new(2019, 6, 20), Time.new(2019, 6, 21)]
      formatted_dates = dates.map { |time| time.strftime('%Y-%m-%d') }
      spec_page_views = formatted_dates.map { |date| [date, rand(11)] }
      spec_downloads = formatted_dates.map { |date| [date, rand(11)] }
      spec_fileset_ids = work.members.map(&:id)

      spec_fileset_ids.each_with_index do |fileset_id, index|
        if index == 0
          expect(Hyrax::Analytics).to receive(:daily_events_for_id).with(fileset_id, 'DownloadIR').and_return(Hyrax::Analytics::Results.new(spec_downloads))
        else
          expect(Hyrax::Analytics).to receive(:daily_events_for_id).with(fileset_id, 'DownloadIR').and_return(Hyrax::Analytics::Results.new([spec_downloads[index]]))
        end
      end

      expect(Hyrax::Analytics).to receive(:daily_events_for_id).with(work.id, 'work-view').and_return(spec_page_views)
      expect(controller).to receive(:add_breadcrumb).with('Home', Hyrax::Engine.routes.url_helpers.root_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.my.works'), Hyrax::Engine.routes.url_helpers.my_works_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.title'), Hyrax::Engine.routes.url_helpers.dashboard_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with('Test title', "/concern/generals/#{work.id}?locale=en")
      get :work, params: { id: work.id }
      expect(response).to be_successful
      pageviews = subject.instance_variable_get('@pageviews')
      downloads = subject.instance_variable_get('@downloads')

      expect(pageviews).to eq(spec_page_views)
      expect(downloads.results).to eq(spec_downloads)
    end
  end

end
