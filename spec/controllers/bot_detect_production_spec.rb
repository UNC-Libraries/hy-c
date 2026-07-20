# frozen_string_literal: true
require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what we want
describe CatalogController, type: :controller do
  before do
    allow(CatalogController).to receive(:turnstile_enabled?).and_return(true)
    allow(BotDetectController).to receive(:cf_challenge_downloads_enabled?).and_return(true)
    request.env['REMOTE_ADDR'] = '0.0.0.0'
  end

  it 'redirects when requested for facet queries' do
    get :index, params: { 'f[creator_label_sim][]': 'test' }
    expect(response).to redirect_to(
                          Rails.application.routes.url_helpers.bot_detect_challenge_path(
                            dest: "/catalog?f#{CGI.escape('[creator_label_sim][]')}=test"
                          )
                        )
  end

  it 'redirects when requested for facet inclusive queries' do
    get :index, params: { 'f_inclusive[access_type_f][]': 'Online' }
    expect(response).to redirect_to(
                          Rails.application.routes.url_helpers.bot_detect_challenge_path(
                            dest: "/catalog?f_inclusive#{CGI.escape('[access_type_f][]')}=Online"
                          )
                        )
  end

  it 'redirects when requested for advanced search queries' do
    get :index, params: { 'clause[0][field]': 'author', 'clause[0][query]': 'Farrell' }
    expect(response).to redirect_to(
                          Rails.application.routes.url_helpers.bot_detect_challenge_path(
                            dest: "/catalog?clause#{CGI.escape('[0][field]')}=author&clause#{CGI.escape('[0][query]')}=Farrell"
                          )
                        )
  end

  it 'redirects when requested for range queries' do
    get :index, params: { 'range[date_issued_isim][begin]': '2000', 'range[date_issued_isim][end]': '2025' }
    expect(response).to redirect_to(
                          Rails.application.routes.url_helpers.bot_detect_challenge_path(
                            dest: "/catalog?range#{CGI.escape('[date_issued_isim][begin]')}=2000&range#{CGI.escape('[date_issued_isim][end]')}=2025"
                          )
                        )
  end

  it 'redirects when requested for paged queries' do
    get :index, params: { page: '10' }
    expect(response).to redirect_to(
                          Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: '/catalog?page=10')
                        )
  end

  it 'redirects when requested for queries with an expired session' do
    session = {
      'bot_detection-passed' => {
        'SESSION_DATETIME_KEY' => (Time.now - 12.hours).to_i,
        'SESSION_IP_KEY' => '0.0.0.0'
      }
    }
    get :index, session: session, params: { 'range[date_issued_isim][begin]': '2000', 'range[date_issued_isim][end]': '2025' }
    expect(response).to redirect_to(
                          Rails.application.routes.url_helpers.bot_detect_challenge_path(
                            dest: "/catalog?range#{CGI.escape('[date_issued_isim][begin]')}=2000&range#{CGI.escape('[date_issued_isim][end]')}=2025"
                          )
                        )
  end

  it 'does not redirect from non facet requests' do
    request.headers['sec-fetch-dest'] = 'empty'
    get :index
    expect(response).to have_http_status(:success)
  end

  it 'does not redirect from post requests' do
    request.headers['sec-fetch-dest'] = 'empty'
    post :index
    expect(response).to have_http_status(:success)
  end

  it 'does not redirect with a valid session' do
    session = {
      'bot_detection-passed' => {
        'SESSION_DATETIME_KEY' => (Time.now + 12.hours).to_i,
        'SESSION_IP_KEY' => '0.0.0.0'
      }
    }
    get :index, session: session, params: { 'range[date_issued_isim][begin]': '2000', 'range[date_issued_isim][end]': '2025' }
    expect(response).to have_http_status(:success)
  end
end

describe Hyrax::DownloadsController, type: :controller do
  routes { Hyrax::Engine.routes }

  before do
    allow(BotDetectController).to receive(:cf_challenge_downloads_enabled?).and_return(true)
    allow(BotDetectController).to receive(:challenge_downloads_enabled?).and_return(true)
    request.env['REMOTE_ADDR'] = '0.0.0.0'

    allow(controller).to receive(:authenticate_user!).and_return(nil)
    allow(controller).to receive(:authorize_download!).and_return(nil)
    allow(controller).to receive(:set_record_admin_set).and_return(nil)

    allow(controller).to receive(:show) { controller.head :ok }
  end

  it 'redirects a normal download request to the challenge page' do
    get :show, params: { id: 'test_file_set_id' }
    expect(response).to redirect_to(
                          Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: '/downloads/test_file_set_id')
                        )
  end

  it 'does not redirect thumbnail download requests' do
    get :show, params: { id: 'test_file_set_id', file: 'thumbnail' }
    expect(response).not_to redirect_to(
                              Rails.application.routes.url_helpers.bot_detect_challenge_path(
                                dest: '/downloads/test_file_set_id?file=thumbnail'
                              )
                            )
  end

  it 'does not redirect GoogleOther download requests' do
    request.headers['User-Agent'] = 'Mozilla/5.0 (compatible; GoogleOther/2.1; +http://www.google.com/bot.html)'
    get :show, params: { id: 'test_file_set_id' }
    expect(response).not_to redirect_to(
                              Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: '/downloads/test_file_set_id')
                            )
  end

  it 'does not redirect when challenge downloads is not enabled' do
    allow(BotDetectController).to receive(:cf_challenge_downloads_enabled?).and_return(false)
    allow(BotDetectController).to receive(:challenge_downloads_enabled?).and_return(false)
    get :show, params: { id: 'test_file_set_id' }
    expect(response).not_to redirect_to(
                              Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: '/downloads/test_file_set_id')
                            )
  end

  it 'does not redirect with a valid session' do
    session = {
      'bot_detection-passed' => {
        'SESSION_DATETIME_KEY' => (Time.now + 12.hours).to_i,
        'SESSION_IP_KEY' => '0.0.0.0'
      }
    }
    get :show, session: session, params: { id: 'test_file_set_id' }
    expect(response).not_to redirect_to(
                              Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: '/downloads/test_file_set_id')
                            )
  end
end
