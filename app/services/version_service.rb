# This service gives the information needed for the version footer, including the git_sha, branch or tag, Hyrax version,
# and date deployed, if in a deployed environment
module VersionService
  def self.git_sha
    if git_directory?
      `git rev-parse HEAD`.chomp
    else
      ''
    end
  end

  def self.branch
    if branch_name == 'HEAD'
      tag_name
    else
      branch_name
    end
  end

  def self.branch_name
    if git_directory?
      `git rev-parse --abbrev-ref HEAD`.chomp
    else
      'not in a git repository'
    end
  end

  def self.tag_name
    if git_directory?
      `git describe --tags`.chomp
    else
      'not in a git repository'
    end
  end

  # When using mutagen, it does not sync the git directory (see https://mutagen.io/documentation/synchronization/version-control-systems)
  # Only run git commands when the project includes a git directory
  def self.git_directory?
    File.directory?('.git')
  end

  def self.deploy_date_phrase
    if Rails.env.production?
      begin
        Date.parse(deploy_date).strftime('Deployed on %B %-d, %Y')
      rescue ArgumentError, TypeError
        'Cannot determine deploy date'
      end
    else
      'Not in deployed environment'
    end
  end

  def self.directory_name
    `pwd -P`.chomp
  end

  def self.deploy_date
    directory_name.match(/\d+/).try(:[], 0)
  end
end
