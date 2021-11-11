require "rails_helper"

RSpec.feature 'logging into the application' do
  context "in production with database auth turned off" do

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:shibboleth] = OmniAuth::AuthHash.new({
        :provider => 'shibboleth',
        :info => {
          :uid => 'atester'
        }
      })
      allow(AuthConfig).to receive(:use_database_auth?).and_return(false)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    end

    it "can find the login link" do
      visit "/advanced?locale=en"
      expect(page).to have_link("Login", href: '/users/sign_in?locale=en')
      click_link("Login")
      expect(page.current_url).to eq "http://www.example.com/Shibboleth.sso/Login?origin=http%3A%2F%2Fwww.example.com%2Fadvanced%3Flocale%3Den&target=%2Fusers%2Fauth%2Fshibboleth%3Flocale%3Den"
    end

    it "can return to the application" do
      visit "/users/auth/shibboleth?origin=http%3A%2F%2Fwww.example.com%2Fadvanced%3Flocale%3Den"
      expect(page).to have_content "Successfully authenticated from Shibboleth account."
      expect(page.current_url).to eq "http://www.example.com/advanced?locale=en"
    end
  end

  context "in production with database auth turned on" do
    let(:user) do
      User.create(email: "test@example.com", guest: false, uid: "test", password: "123456")
    end

    before do
      allow(AuthConfig).to receive(:use_database_auth?).and_return(true)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    end

    it "can log in using database authentication and redirect to the homepage" do
      user.reload
      visit "/advanced?locale=en"
      expect(page).to have_link("Login", href: '/users/sign_in?locale=en')
      click_link("Login")
      expect(page.current_url).to eq "http://www.example.com/users/sign_in?locale=en"
      fill_in 'Onyen', with: 'test'
      fill_in 'Password', with: '123456'
      click_button("Log in")
      expect(page).to have_content "Signed in successfully."
      expect(page.current_url).to eq "http://www.example.com/?locale=en"
    end
  end
end
