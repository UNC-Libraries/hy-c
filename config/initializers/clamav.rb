# frozen_string_literal: true
require 'fileutils'
require 'clamby'

ClamAV.instance.loaddb if defined? ClamAV

if defined? Clamby
  clamby_config = { daemonize: true }

  if ENV['CLAMD_CONFIG_FILE'].present?
    clamby_config[:config_file] = ENV['CLAMD_CONFIG_FILE']
    clamby_config[:stream] = true
    clamby_config[:fdpass] = false
  elsif ENV['CLAMD_TCP_HOST'].present?
    clamdscan_config_path = Rails.root.join('tmp', 'clamby-clamdscan.conf')
    FileUtils.mkdir_p(clamdscan_config_path.dirname)
    File.write(clamdscan_config_path, <<~CONF)
      TCPAddr #{ENV.fetch('CLAMD_TCP_HOST')}
      TCPSocket #{ENV.fetch('CLAMD_TCP_PORT', '3310')}
    CONF

    clamby_config[:config_file] = clamdscan_config_path.to_s
    clamby_config[:stream] = true
    clamby_config[:fdpass] = false
  else
    # Fdpass only works over a local Unix socket; keep that behavior for non-TCP setups.
    clamby_config[:fdpass] = true
  end

  # Treat daemon connection failures as hard failures so we don't silently misclassify scans.
  clamby_config[:error_clamscan_client_error] = !Rails.env.test?

  Rails.logger.info("Configuring Clamby with #{clamby_config.except(:config_file).inspect}")
  Rails.logger.info("Using Clamby config file #{clamby_config[:config_file]}") if clamby_config[:config_file].present?

  Clamby.configure(clamby_config)
else
  Rails.logger.warn('Clamby is not available during initialization; virus scanning may fall back to the null scanner')
end
