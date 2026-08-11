# frozen_string_literal: true
require 'yaml'
# Set up bootsnap caching directory from local_env.yml, if its not already set
unless ENV['BOOTSNAP_CACHE_DIR']
  begin
    local_env = YAML.load_file(File.expand_path('local_env.yml', __dir__))
    ENV['BOOTSNAP_CACHE_DIR'] = local_env['BOOTSNAP_CACHE_DIR'] if local_env['BOOTSNAP_CACHE_DIR']
  rescue
    # local_env.yml not available, BOOTSNAP_CACHE_DIR left unset
  end
end

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Set up bootsnap for gem requirement caching
