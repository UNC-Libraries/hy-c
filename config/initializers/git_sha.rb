GIT_SHA = VersionService.git_sha
BRANCH = VersionService.branch
Rails.logger.debug("in initializer: #{Rails.env}")
LAST_DEPLOYED = VersionService.deploy_date_phrase

HYRAX_VERSION = Gem.loaded_specs['hyrax'].version.to_s
