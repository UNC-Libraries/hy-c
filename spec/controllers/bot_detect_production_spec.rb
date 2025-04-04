# frozen_string_literal: true
require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what we want
describe CatalogController, type: :controller do
  before do
    allow(CatalogController).to receive(:turnstile_enabled?).and_return(true)
  end

  it 'redirects when requested for facet queries' do
    get :index, params: { 'f[creator_label_sim][]': 'test' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: "/catalog?f#{CGI.escape('[creator_label_sim][]')}=test"))
  end

  it 'redirects when requested for facet inclusive queries' do
    get :index, params: { 'f_inclusive[access_type_f][]': 'Online' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: "/catalog?f_inclusive#{CGI.escape('[access_type_f][]')}=Online"))
  end

  it 'redirects when requested for advanced search queries' do
    get :index, params: { 'clause[0][field]': 'author', 'clause[0][query]': 'Farrell' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: "/catalog?clause#{CGI.escape('[0][field]')}=author&clause#{CGI.escape('[0][query]')}=Farrell"))
  end

  it 'redirects when requested for range queries' do
    get :index, params: { 'range[date_issued_isim][begin]': '2000', 'range[date_issued_isim][end]': '2025' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: "/catalog?range#{CGI.escape('[date_issued_isim][begin]')}=2000&range#{CGI.escape('[date_issued_isim][end]')}=2025"))
  end

  it 'redirects when requested for paged queries' do
    get :index, params: { 'page': '10' }
    expect(response).to redirect_to(Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: '/catalog?page=10'))
  end

  it 'redirects when requested for queries with an expired session' do
    session = {
      'bot_detection-passed': {
        'SESSION_DATETIME_KEY' => (Time.now - 12.hours).to_i,
        'SESSION_IP_KEY' => '0.0.0.0'
      }
    }
    get :index, session: session, params: { 'range[date_issued_isim][begin]': '2000', 'range[date_issued_isim][end]': '2025' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(Rails.application.routes.url_helpers.bot_detect_challenge_path(dest: "/catalog?range#{CGI.escape('[date_issued_isim][begin]')}=2000&range#{CGI.escape('[date_issued_isim][end]')}=2025"))
  end

  it 'does not redirect from non facet requests' do
    request.headers['sec-fetch-dest'] = 'empty'
    get :index
    expect(response).to have_http_status(:success) # not a redirect
  end

  it 'does not redirect from post requests' do
    request.headers['sec-fetch-dest'] = 'empty'
    post :index
    expect(response).to have_http_status(:success) # not a redirect
  end

  it 'does not redirect with a valid session' do
    session = {
      'bot_detection-passed': {
        'SESSION_DATETIME_KEY' => (Time.now + 12.hours).to_i,
        'SESSION_IP_KEY' => '0.0.0.0'
      }
    }
    get :index, session: session, params: { 'range[date_issued_isim][begin]': '2000', 'range[date_issued_isim][end]': '2025' }
    expect(response).to have_http_status(:success) # not a redirect
  end
end
