# frozen_string_literal: true

Webdrivers.cache_time = 3

# Setup chrome headless driver
Capybara.server = :webrick

Capybara.register_driver :chrome_headless do |app|
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 120

  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')

  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome

  Capybara::Selenium::Driver.new(app, browser: :chrome, capabilities: [options, capabilities], http_client: client)
end

Capybara.javascript_driver = :chrome_headless
