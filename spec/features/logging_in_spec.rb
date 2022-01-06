require "rails_helper"

RSpec.feature 'logging into the application' do
  context "in production with database auth turned off" do
    let(:escaped_origin) { CGI.escape("http://www.example.com/advanced?locale=en") }
    let(:escaped_target) { CGI.escape("/users/auth/shibboleth/callback?locale=en") }

    before do
      allow(AuthConfig).to receive(:use_database_auth?).and_return(false)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    end

    it "can find the login link" do
      visit "/advanced?locale=en"
      expect(page).to have_link("Login", href: '/users/sign_in?locale=en')
      click_link("Login")
      expect(page.current_url).to eq "http://www.example.com/Shibboleth.sso/Login?target=/users/auth/shibboleth/callback?locale=en%26origin=#{escaped_origin}"
    end
    context "with shibboleth mocked" do
      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:shibboleth] = OmniAuth::AuthHash.new({
          :provider => 'shibboleth',
          :info => {
            :uid => 'atester'
          }
        })
      end

      it "can return to the application" do
        visit "/users/auth/shibboleth/callback?locale=en&origin=http://www.example.com/advanced?locale=en"
        expect(page).to have_content "Successfully authenticated from Shibboleth account."
        expect(page.current_url).to eq "http://www.example.com/advanced?locale=en"
        expect(page).to have_content "atester"
      end

      it "returns to the root path if the origin is garbage" do
        visit "/users/auth/shibboleth/callback?locale=en&origin=://sdfgdfg.com"
        expect(page).to have_content "Successfully authenticated from Shibboleth account."
        expect(page.current_url).to eq "http://www.example.com/?locale=en"
      end

      it "returns to the root path if the origin does not match the host" do
        visit "/users/auth/shibboleth/callback?locale=en&origin=http://fake.example.com"
        expect(page).to have_content "Successfully authenticated from Shibboleth account."
        expect(page.current_url).to eq "http://www.example.com/?locale=en"
      end
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
      # The database auth does not return you to the original page
      expect(page.current_url).to eq "http://www.example.com/?locale=en"
    end
  end
end
