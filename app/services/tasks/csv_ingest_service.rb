# frozen_string_literal: true
module Tasks
  # require 'csv'
  require 'tasks/migrate/services/progress_tracker'
  require 'tasks/migration_helper'

  class CsvIngestService

    attr_reader :config

    def initialize(args)
      @config = YAML.load_file(args[:configuration_file])
    end

    def ingest
      # config file with worktype, adminset, depositor, file locations
      puts "[#{Time.now}] Start ingest of #{@config['batch_name']} in #{@config['metadata_file']}"

      admin_set_id = ::AdminSet.where(title: @config['admin_set']).first.id

      # read csv with headers
      data = CSV.read(File.join(@config['metadata_dir'], @config['metadata_file']), headers: true)
      puts "[#{Time.now}] loaded #{@config['batch_name']} data"

      # create deposit record
      create_deposit_record

      # Progress tracker for objects migrated
      @object_progress = Migrate::Services::ProgressTracker.new(@config['progress_log'])
      @skipped_objects = Migrate::Services::ProgressTracker.new(@config['skipped_log'])
      already_ingested = @object_progress.completed_set + @skipped_objects.completed_set

      # iterate through data
      data.each_with_index do |row, index|
        # Skip this item if it has been ingested before
        if already_ingested.include?(row['source_identifier'])
          puts "Skipping previously ingested #{row['source_identifier']} #{index + 1} out of #{data.count}"
          next
        end

        begin
          puts '', "[#{Time.now}] ingesting #{row['source_identifier']} (#{index + 1} of #{data.count})"

          # parse metadata and file names; add deposit record id to metadata
          work_attributes = row.to_h.except('source_identifier', 'files', 'model')
          work_attributes.select { |k, _v| k.to_s.ends_with? '_attributes' }.each do |k, v|
            work_attributes[k] = JSON.parse(v.gsub('=>', ':').gsub("\\'", '||').gsub("'", '"').gsub('; ', ', ').gsub('||', "'"))
          end
          work_attributes['subject'] = work_attributes['subject'].split('; ')
          work_attributes['deposit_record'] = @deposit_record_id
          work_attributes['label'] = Array.wrap(work_attributes['title']).first
          work_attributes['rights_statement_label'] = CdrRightsStatementsService.label(work_attributes['rights_statement'])
          work_attributes['license_label'] = CdrLicenseService.label(work_attributes['license'])

          # create work with metadata in workflow
          work = @config['work_type'].singularize.classify.constantize.new
          work.depositor = @config['depositor_onyen']
          work.admin_set_id = admin_set_id
          work.visibility = @config['work_visibility']

          work = MigrationHelper.check_enumeration(work_attributes, work, row['source_identifier'])

          work.save!
          puts "[#{Time.now}] #{row['source_identifier']},#{work.id} saved new article"

          work.update permissions_attributes: MigrationHelper.get_permissions_attributes(admin_set_id)

          # Create sipity record
          workflow = Sipity::Workflow.joins(:permission_template)
                                     .where(permission_templates: { source_id: work.admin_set_id }, active: true)

          workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
          Sipity::Entity.create!(proxy_for_global_id: work.to_global_id.to_s,
                                 workflow: workflow.first,
                                 workflow_state: workflow_state.first)

          # attach files
          unless row['files'].blank?
            files = row['files'].split('; ')
            puts "[#{Time.now}] #{row['source_identifier']} attaching files"
            file_count = files.count
            attached_file_count = 0

            # make pdf file first file attached for thumbnail purposes
            pdf_file = files.select { |filename| filename.include? 'WEB' }
            files.delete(pdf_file.first)
            files = pdf_file + files

            files.each_with_index do |filename, file_index|
              puts "[#{Time.now}] #{row['source_identifier']} attaching file #{file_index + 1} of #{file_count}"

              file_visibility = @config['file_visibility']

              # parse filename
              if filename.include? 'EPUB'
                filename_with_extension = "#{filename}.epub"
              elsif filename.include? 'WEB'
                filename_with_extension = "#{filename}.pdf"
              else
                puts "[#{Time.now}] #{row['source_identifier']} skipping file with nonstandard filename: #{filename}"
                next
              end

              file_path = File.join(@config['metadata_dir'], filename_with_extension)
              if File.exist?(file_path)
                # create and save file
                file_attributes = { title: [filename] }
                file_set = FileSet.create(file_attributes)
                actor = Hyrax::Actors::FileSetActor.new(file_set, User.where(uid: @config['depositor_onyen']).first)
                actor.create_metadata(file_attributes)
                file = File.open(file_path)
                actor.create_content(file)
                actor.attach_to_work(work)
                file.close

                file_set.visibility = file_visibility
                file_set.save!

                attached_file_count += 1

                puts "[#{Time.now}] #{row['source_identifier']},#{work.id} saved file #{file_index + 1} of #{file_count}"
              else
                puts "[#{Time.now}] #{row['source_identifier']},#{work.id} could not find file #{file_path}"
              end
            end
          end
          @object_progress.add_entry(row['source_identifier'])
        rescue StandardError => e
          puts "[#{Time.now}] there was an error processing #{row['source_identifier']}: #{e.message}"
          @skipped_objects.add_entry(row['source_identifier'])
        end
      end

      puts "[#{Time.now}] Completed ingest of #{@config['batch_name']} in #{@config['metadata_file']}"
    end

    private

    def create_deposit_record
      if File.exist?(@config['deposit_record_id_log']) && !File.zero?(@config['deposit_record_id_log'])
        @deposit_record_id = (File.open(@config['deposit_record_id_log']) { |f| f.readline }).strip
        puts "[#{Time.now}] loaded deposit record id for batch"
      else
        deposit_record = DepositRecord.new({ title: @config['deposit_title'],
                                             deposit_method: @config['deposit_method'],
                                             deposit_package_type: @config['deposit_type'],
                                             deposit_package_subtype: @config['deposit_subtype'],
                                             deposited_by: @config['depositor_onyen'] })
        # attach metadata file to deposit record
        original_metadata = FedoraOnlyFile.new({ 'title' => @config['metadata_file'],
                                                 'deposit_record' => deposit_record })
        original_metadata.file.content = File.open(File.join(@config['metadata_dir'], @config['metadata_file']))
        original_metadata.save!
        deposit_record[:manifest] = [original_metadata.uri]
        deposit_record.save!
        @deposit_record_id = deposit_record.uri
        File.open(@config['deposit_record_id_log'], 'a+') do |f|
          f.puts @deposit_record_id
        end

        puts "[#{Time.now}] created deposit record for #{@config['batch_name']} batch"
      end
    end
  end
end
