# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  # Adjusts the permissions of a list of works and their filesets to grant permissions
  # assigned to their admin set.
  class GroupPermissionRemediationService
    def self.run(id_list_file, admin_set_id)
      GroupPermissionRemediationService.new(id_list_file, admin_set_id).run
    end

    def initialize(id_list_file, admin_set_id)
      @id_list_file = id_list_file
      @admin_set_id = admin_set_id
    end

    def run
      work_id_list.each do |work_id|
        start_time = Time.now
        work_id = work_id.chomp
        begin
          work = ActiveFedora::Base.find(work_id)
          logger.info("Remediating groups for #{work_id}")
          work.update permissions_attributes: group_permissions
          work.file_sets.each do |file_set|
            file_set.update permissions_attributes: group_permissions
          end
          logger.info("Completed remediation of #{work_id} in #{Time.now - start_time}")
        rescue StandardError => e
          logger.error("Failed to update #{work_id}:")
          logger.error(e)
        end
      end
    end

    def work_id_list
      @work_id_list ||= File.readlines(@id_list_file)
    end

    def group_permissions
      @group_permissions ||= WorkUtilsHelper.get_permissions_attributes(@admin_set_id)
    end

    def logger
      @logger ||= begin
        log_path = File.join(Rails.configuration.log_directory, 'remediate_permissions.log')
        Logger.new(log_path, progname: 'remediate')
      end
    end
  end
end
