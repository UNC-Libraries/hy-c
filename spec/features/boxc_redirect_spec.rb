require 'rails_helper'

# before actions
RSpec.feature 'boxc redirects' do
  let(:tempfile) { Tempfile.new('redirect_uuids.csv', 'spec/fixtures/') }
  before do
    tempfile
    File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
      f.puts 'uuid,new_path'
    end
    stub_request(:any, 'https://dcr-test.lib.unc.edu/list/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6').to_return(status: 200)
  end

  after do
    tempfile.unlink
    File.delete('spec/fixtures/redirect_uuids.csv') if File.exist?('spec/fixtures/redirect_uuids.csv')
  end
  around(:all) do |example|
    cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
    cached_redirect_old_domain = ENV['REDIRECT_OLD_DOMAIN']
    cached_redirect_new_domain = ENV['REDIRECT_NEW_DOMAIN']
    ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
    ENV['REDIRECT_OLD_DOMAIN'] = ENV['HYRAX_HOST'].gsub('https://','')
    ENV['REDIRECT_NEW_DOMAIN'] = 'dcr-test.lib.unc.edu'
    # example.run is where the test actually runs
    example.run
    ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
    ENV['REDIRECT_OLD_DOMAIN'] = cached_redirect_old_domain
    ENV['REDIRECT_NEW_DOMAIN'] = cached_redirect_new_domain
  end

  describe '#check_redirect' do
    scenario 'non-boxc url' do
      article = Article.create(title: ['test article'], visibility: 'open')

      visit "#{ENV['HYRAX_HOST']}/concern/articles/#{article.id}"
      expect(current_path).to eq "/concern/articles/#{article.id}"
    end

    scenario 'migrated work url' do
      article = Article.create(title: ['new article'], visibility: 'open')
      File.open(ENV['REDIRECT_FILE_PATH'], 'a+') do |f|
        f.puts "02fc897a-12b6-4b81-91e4-b5e29cb683a6,articles/#{article.id}"
      end

      visit "#{ENV['HYRAX_HOST']}/record/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
      expect(current_path).to eq "/concern/articles/#{article.id}"

      File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
        f.puts 'uuid,new_path'
      end
    end

    scenario 'boxc search url' do
      visit "#{ENV['HYRAX_HOST']}/search/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6?anywhere=term"
      expect(current_path).to eq '/concern/404'
    end

    scenario 'boxc listContent url' do
      visit "#{ENV['HYRAX_HOST']}/listContent/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6?anywhere=term"
      expect(current_path).to eq '/concern/404'
    end

    scenario 'boxc record not in hyc' do
      visit "#{ENV['HYRAX_HOST']}/record/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
      expect(current_url).to eq "https://#{ENV['REDIRECT_NEW_DOMAIN']}/record/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
    end

    scenario 'boxc other url' do
      visit "#{ENV['HYRAX_HOST']}/search?anywhere=term"
      expect(current_path).to eq '/concern/404'

      # redirected to dcr-test, then to hy-c home page since testing env cannot check outside links
      visit "#{ENV['HYRAX_HOST']}/list/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
      expect(current_url).to eq "https://#{ENV['REDIRECT_NEW_DOMAIN']}/list/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
    end
  end

  describe '#after_sign_in_path_for' do
    let(:admin) { FactoryBot.create(:admin, password: 'password') }
    scenario 'visiting a private work page' do
      private_article = Article.create(title: ['test article'])

      visit "#{ENV['HYRAX_HOST']}/concern/articles/#{private_article.id}"
      expect(current_path).to eq '/users/sign_in'

      fill_in 'Onyen', with: admin.uid
      fill_in 'Password', with: 'password'
      click_button 'Log in'

      expect(current_path).to eq "/concern/articles/#{private_article.id}"
    end
  end
end
