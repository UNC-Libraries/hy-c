# frozen_string_literal: true

Capybara.server = :webrick

def find_executable(commands: [], paths: [])
  from_path = commands.map { |command| `command -v #{command} 2>/dev/null`.strip }
  (from_path + paths).reject(&:empty?).uniq.find { |path| File.executable?(path) }
end

Capybara.register_driver :chrome_headless do |app|
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 120

  chrome_binary = find_executable(
    commands: %w[google-chrome-stable google-chrome chromium chromium-browser],
    paths: %w[/usr/bin/google-chrome-stable /opt/google/chrome/chrome /usr/bin/chromium /usr/bin/chromium-browser /snap/bin/chromium]
  )

  chromedriver_path = find_executable(
    commands: ['chromedriver'],
    paths: %w[/usr/bin/chromedriver /usr/local/bin/chromedriver]
  )

  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = chrome_binary if chrome_binary

  %w[
    --headless
    --no-sandbox
    --disable-dev-shm-usage
    --disable-gpu
    --no-zygote
    --disable-software-rasterizer
    --remote-debugging-port=0
    --window-size=1400,1400
  ].each { |argument| options.add_argument(argument) }

  service = chromedriver_path ? Selenium::WebDriver::Service.chrome(path: chromedriver_path) : Selenium::WebDriver::Service.chrome

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
