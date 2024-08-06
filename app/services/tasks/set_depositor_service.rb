# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  # Sets the depositor for a list of objects
  class SetDepositorService
    def self.run(id_list_file, depositor_id)
      SetDepositorService.new(id_list_file, depositor_id).run
    end

    def initialize(id_list_file, depositor_id)
      @id_list_file = id_list_file
      @depositor_id = depositor_id
    end

    def run
      logger.info("Updating #{object_id_list.count} objects to have depositor #{@depositor_id}")
      object_id_list.each do |object_id|
        start_time = Time.now
        object_id = object_id.chomp
        begin
          target = ActiveFedora::Base.find(object_id)
          target.depositor = depositor.user_key
          target.save!
          logger.info("Updated depositor of #{object_id} to #{@depositor_id} in #{Time.now - start_time}")
        rescue Ldp::Gone
          logger.warn("Skipped deleted object #{object_id}")
        rescue StandardError => e
          logger.error("Failed to update #{object_id}:")
          logger.error(e)
        end
      end
    end

    def object_id_list
      @object_id_list ||= File.readlines(@id_list_file)
    end

    def depositor
      @depositor ||= User.find_by(uid: @depositor_id)
    end

    def logger
      @logger ||= begin
        log_path = File.join(Rails.configuration.log_directory, 'set_depositor.log')
        Logger.new(log_path, progname: 'set_depositor')
      end
    end
  end
end
