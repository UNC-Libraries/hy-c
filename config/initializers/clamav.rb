# frozen_string_literal: true
# Rails 7 / Zeitwerk can't resolve app/ constants during initializers — defer to after_initialize.
Rails.application.config.after_initialize do
  Hyrax.config.virus_scanner = Hyc::VirusScanner
end
