# frozen_string_literal: true
require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what we want
describe CatalogController, type: :controller do
  before do
    allow(ENV).to receive(:fetch)
            .with('CF_TURNSTILE_ENABLED')
            .and_return('true')
  end

  it 'redirects when requested for facet queries' do
    get :index, params: { 'f[creator_label_sim][]': 'test' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(bot_detect_challenge_path(dest: "/catalog?f#{CGI.escape('[creator_label_sim][]')}=test"))
  end

  it 'redirects when requested for facet inclusive queries' do
    get :index, params: { 'f_inclusive[access_type_f][]': 'Online' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(bot_detect_challenge_path(dest: "/catalog?f_inclusive#{CGI.escape('[access_type_f][]')}=Online"))
  end

  it 'redirects when requested for advanced search queries' do
    get :index, params: { 'clause[0][field]': 'author', 'clause[0][query]': 'Farrell' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(bot_detect_challenge_path(dest: "/catalog?clause#{CGI.escape('[0][field]')}=author&clause#{CGI.escape('[0][query]')}=Farrell"))
  end

  it 'redirects when requested for range queries' do
    get :index, params: { 'range[date_issued_isim][begin]': '2000', 'range[date_issued_isim][end]': '2025' }
    # Rspec has a very hard time with the funky facet syntax in hyrax. They seem to get double escaped, but this doesn't impact actual redirects
    expect(response).to redirect_to(bot_detect_challenge_path(dest: "/catalog?range#{CGI.escape('[date_issued_isim][begin]')}=2000&range#{CGI.escape('[date_issued_isim][end]')}=2025"))
  end

  it 'does not redirect from non facet requests' do
    stub_request(:get, 'http://127.0.0.1:8983/solr/blacklight-core/select?collection.defType=lucene&collection.fl=*&collection.q=%7B!terms%20f=id%20v=$row._root_%7D&collection.rows=1&f.access_subjects_ssim.facet.limit=11&f.collection_ssim.facet.limit=11&f.creator_ssim.facet.limit=11&f.geogname_ssim.facet.limit=11&f.level_ssim.facet.limit=11&f.names_ssim.facet.limit=11&f.repository_ssim.facet.limit=11&facet=true&facet.field=access_subjects_ssim&facet.query=has_online_content_ssim:true&fl=*,collection:%5Bsubquery%5D&hl=true&hl.fl=text&hl.snippets=3&rows=10&sort=score%20desc,%20title_sort%20asc&stats=true&stats.field=date_range_isim&wt=json').
      to_return(status: 200, body: '', headers: {})
    request.headers['sec-fetch-dest'] = 'empty'
    get :index
    expect(response).to have_http_status(:success) # not a redirect
  end
end
