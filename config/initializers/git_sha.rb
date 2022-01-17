GIT_SHA = `git rev-parse HEAD`.chomp
branch_name = `git rev-parse --abbrev-ref HEAD`.chomp
git_tag_name = `git describe --tags`.chomp
BRANCH = if branch_name == 'HEAD'
           git_tag_name
         else
           branch_name
         end
Rails.logger.debug("in initializer: #{Rails.env}")
LAST_DEPLOYED = if Rails.env.production?
                  # on cdr-test this returns /net/deploy/ir/test/releases/DEPLOY_DATE
                  # e.g. /net/deploy/ir/test/releases/20211202095413
                  directory_name = `pwd -P`.chomp
                  deploy_date = directory_name.match(/\d+/).try(:[], 0)
                  begin
                    Date.parse(deploy_date).strftime('Deployed on %B %-d, %Y')
                  rescue ArgumentError, TypeError
                    'Cannot determine deploy date'
                  end
                else
                  'Not in deployed environment'
                end

HYRAX_VERSION = Gem.loaded_specs['hyrax'].version.to_s
