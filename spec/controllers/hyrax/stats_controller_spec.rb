# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Hyrax::StatsController do
  let(:user) { FactoryBot.create(:user) }
  let(:usage) { double }

  before do
    allow_any_instance_of(User).to receive(:groups).and_return([])
  end
  routes { Hyrax::Engine.routes }

  describe 'work' do
    let(:work) { FactoryBot.create(:work_with_files, user: user) }

    before do
      sign_in user
      request.env['HTTP_REFERER'] = 'http://test.host/foo'
    end

    it 'renders the stats view' do
      expect(Hyrax::Analytics).to receive(:daily_events_for_id).with(work.id, 'work-view').and_return([])
      file1_events = Hyrax::Analytics::Results.new([[Time.new(2019, 6, 19), 6], [Time.new(2019, 6, 20), 0], [Time.new(2019, 6, 21), 3]])
      file2_events = Hyrax::Analytics::Results.new([[Time.new(2019, 6, 19), 0], [Time.new(2019, 6, 20), 0], [Time.new(2019, 6, 21), 1]])
      expect(Hyrax::Analytics).to receive(:daily_events_for_id).with(work.members[0].id, 'download-ir').and_return(file1_events)
      expect(Hyrax::Analytics).to receive(:daily_events_for_id).with(work.members[1].id, 'download-ir').and_return(file2_events)
      expect(controller).to receive(:add_breadcrumb).with('Home', Hyrax::Engine.routes.url_helpers.root_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.my.works'), Hyrax::Engine.routes.url_helpers.my_works_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.title'), Hyrax::Engine.routes.url_helpers.dashboard_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with('Test title', "/concern/generals/#{work.id}?locale=en")
      get :work, params: { id: work }
      expect(response).to be_successful
      downloads = subject.instance_variable_get('@downloads')
      expect(downloads.results).to eq [[Time.new(2019, 6, 19), 6], [Time.new(2019, 6, 20), 0], [Time.new(2019, 6, 21), 4]]
    end
  end
end
