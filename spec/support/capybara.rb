# frozen_string_literal: true

Capybara.server = :webrick

Capybara.register_driver :chrome_headless do |app|
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 120

  chrome_binary = '/snap/bin/chromium'
  chromedriver_path = '/usr/bin/chromedriver'

  raise "Chrome binary does not exist: #{chrome_binary}" unless File.file?(chrome_binary)
  raise "Chrome binary is not executable: #{chrome_binary}" unless File.executable?(chrome_binary)
  raise "ChromeDriver does not exist: #{chromedriver_path}" unless File.file?(chromedriver_path)
  raise "ChromeDriver is not executable: #{chromedriver_path}" unless File.executable?(chromedriver_path)

  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = chrome_binary

  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')

  service = Selenium::WebDriver::Service.chrome(
    path: chromedriver_path
  )

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options,
    service: service,
    http_client: client
  )
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :chrome_headless
