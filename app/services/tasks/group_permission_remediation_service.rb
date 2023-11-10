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
        work = ActiveFedora::Base.find(work_id)
        work.update permissions_attributes: group_permissions
        work.file_sets.each do |file_set|
          file_set.update permissions_attributes: group_permissions
        end
      end
    end

    def work_id_list
      @work_id_list ||= File.readlines(@id_list_file)
    end

    def group_permissions
      @group_permissions ||= MigrationHelper.get_permissions_attributes(@admin_set_id)
    end
  end
end
