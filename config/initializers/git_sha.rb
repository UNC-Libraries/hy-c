GIT_SHA = `git rev-parse HEAD`.chomp
BRANCH = `git rev-parse --abbrev-ref HEAD`.chomp
Rails.logger.debug("in initializer: #{Rails.env}")
LAST_DEPLOYED = if Rails.env.production?
                  # on cdr-test this returns /net/deploy/ir/test/releases/DEPLOY_DATE
                  # e.g. /net/deploy/ir/test/releases/20211202095413
                  directory_name = `pwd -P`.chomp
                  deploy_date = directory_name.match(/\d+/).try(:[], 0)
                  begin
                    Date.parse(deploy_date).strftime("deployed on %B %-d, %Y")
                  rescue ArgumentError, TypeError
                    "cannot determine deploy date"
                  end
                else
                  "not in deployed environment"
                end

HYRAX_VERSION = Gem.loaded_specs["hyrax"].version.to_s
