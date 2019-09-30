require 'rails_helper'

# before actions
RSpec.feature 'boxc redirects' do
  cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
  cached_redirect_old_domain = ENV['REDIRECT_OLD_DOMAIN']
  cached_redirect_new_domain = ENV['REDIRECT_NEW_DOMAIN']

  before(:each) do
    ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
    ENV['REDIRECT_OLD_DOMAIN'] = 'localhost:4040/regex'
    ENV['REDIRECT_NEW_DOMAIN'] = 'dcr-test.lib.unc.edu'
  end

  after(:each) do
    ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
    ENV['REDIRECT_OLD_DOMAIN'] = cached_redirect_old_domain
    ENV['REDIRECT_NEW_DOMAIN'] = cached_redirect_new_domain
  end

  describe '#check_redirect' do
    scenario 'non-boxc url' do
      article = Article.create(title: ['test article'], visibility: 'open')

      visit "#{ENV['HYRAX_HOST']}/concern/#{Array.wrap(article.class.to_s).first.downcase}s/#{article.id}"
      expect(current_path).to eq "/concern/#{Array.wrap(article.class.to_s).first.downcase}s/#{article.id}"
    end

    scenario 'migrated work url' do
      article = Article.create(title: ['new article'], visibility: 'open')
      File.open('spec/fixtures/redirect_uuids.csv', 'a+') do |f|
        f.puts "02fc897a-12b6-4b81-91e4-b5e29cb683a6,articles/#{article.id}"
      end

      visit "#{ENV['HYRAX_HOST']}/record/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
      expect(current_path).to eq "/concern/#{Array.wrap(article.class.to_s).first.downcase}s/#{article.id}"

      File.open('spec/fixtures/redirect_uuids.csv', 'w') do |f|
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
      # redirected to dcr-test, then to hy-c home page since testing env cannot check outside links
      # regex for sending people to dcr expects a domain+'.', so '/regex.' was added to gsub localhost:4040
      visit "#{ENV['HYRAX_HOST']}/regex./record/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
      expect(current_path).to eq '/'
    end

    scenario 'boxc other url' do
      visit "#{ENV['HYRAX_HOST']}/search?anywhere=term"
      expect(current_path).to eq '/concern/404'

      # redirected to dcr-test, then to hy-c home page since testing env cannot check outside links
      visit "#{ENV['HYRAX_HOST']}/regex./list/uuid:02fc897a-12b6-4b81-91e4-b5e29cb683a6"
      expect(current_path).to eq '/'
    end
  end

  describe '#after_sign_in_path_for' do
    scenario 'visiting a private work page' do
      private_article = Article.create(title: ['test article'])

      visit "#{ENV['HYRAX_HOST']}/concern/#{Array.wrap(private_article.class.to_s).first.downcase}s/#{private_article.id}"
      expect(current_path).to eq '/users/sign_in'

      fill_in 'Onyen', with: 'admin'
      fill_in 'Password', with: 'password'
      click_button 'Log in'

      expect(current_path).to eq "/concern/#{Array.wrap(private_article.class.to_s).first.downcase}s/#{private_article.id}"
    end
  end
end
