# frozen_string_literal: true
# Rails 7 / Zeitwerk can't resolve app/ constants during initializers — require explicitly.
require Rails.root.join('app/services/version_service')
GIT_SHA = VersionService.git_sha
BRANCH = VersionService.branch
Rails.logger.debug("in initializer: #{Rails.env}")
LAST_DEPLOYED = VersionService.deploy_date_phrase

HYRAX_VERSION = Gem.loaded_specs['hyrax'].version.to_s
