module Migrate
  module Services
    require 'tasks/migrate/services/id_mapper'
    require 'tasks/migrate/services/metadata_parser'
    require 'tasks/migrate/services/progress_tracker'
    require 'tasks/migration_helper'

    class IngestService

      def initialize(config, object_hash, binary_hash, premis_hash, deposit_record_hash, output_dir, depositor, collection)
        @collection_ids_file = config['collection_list']
        @object_hash = object_hash
        @binary_hash = binary_hash
        @premis_hash = premis_hash
        @deposit_record_hash = deposit_record_hash
        @work_type = config['work_type']
        @child_work_type = config['child_work_type']
        @depositor = depositor
        @tmp_file_location = config['tmp_file_location']
        @config = config
        @output_dir = output_dir
        @collection_name = config['collection_name']
        @run_skipped = config['run_skipped'] || false

        admin_set = config['admin_set']
        if admin_set.blank?
          @admin_set_id = (AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first).id
        else
          @admin_set_id = (AdminSet.where(title: config['admin_set']).first).id
          raise "Unable to find admin set #{admin_set}" if @admin_set_id.blank?
        end

        child_admin_set = config['child_admin_set']
        unless child_admin_set.blank?
          @child_admin_set_id = (AdminSet.where(title: child_admin_set).first).id
          raise "Unable to find child admin set #{child_admin_set}" if @child_admin_set_id.blank?
        end

        # Create file and hash mapping new and old ids
        @id_mapper = Migrate::Services::IdMapper.new(File.join(@output_dir, 'old_to_new.csv'), 'old', 'new')
        # Store parent-child relationships
        @parent_child_mapper = Migrate::Services::IdMapper.new(File.join(@output_dir, "#{collection}_parent_child.csv"), 'parent', 'children')
        # Progress tracker for objects migrated
        @object_progress = Migrate::Services::ProgressTracker.new(File.join(@output_dir, 'object_progress.log'))
        # Skipped object tracker
        @skipped_objects = Migrate::Services::ProgressTracker.new(File.join(@output_dir, 'skipped_objects.log'))
      end

      def ingest_records
        vis_private = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        vis_authenticated = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED

        STDOUT.sync = true
        # get array of record uuids
        collection_uuids = MigrationHelper.get_collection_uuids(@collection_ids_file)

        already_migrated = @object_progress.completed_set
        puts "Skipping #{already_migrated.length} previously migrated works"

        unless @run_skipped
          already_migrated += @skipped_objects.completed_set
          puts 'Skipping previously skipped works'
        end

        puts "[#{Time.now.to_s}] Object count:  #{collection_uuids.count.to_s}"

        # get metadata for each record
        collection_uuids.each_with_index do |uuid, index|
          # Skip this item if it has been migrated before
          if already_migrated.include?(uuid)
            puts "Skipping previously ingested #{uuid}"
            next
          end

          file_path = @object_hash[uuid]
          unless File.file?(file_path)
            @skipped_objects.add_entry(uuid)
            puts "Skipping #{uuid} with invalid file path, #{file_path}"
            next
          end

          start_time = Time.now
          puts "[#{start_time.to_s}] #{uuid} Start migration, #{index + 1} out of #{collection_uuids.count}"
          work_attributes = Migrate::Services::MetadataParser.new(file_path,
                                                                  @object_hash,
                                                                  @binary_hash,
                                                                  @deposit_record_hash,
                                                                  collection_uuids,
                                                                  @depositor,
                                                                  @collection_name,
                                                                  @admin_set_id).parse
          puts "[#{Time.now.to_s}] #{uuid} metadata parsed in #{Time.now - start_time} seconds"

          # save group permissions info and remove from work attribute hash since it is not a valid work attribute
          group_permissions = work_attributes['permissions_attributes']

          # Create new work record and save
          new_work = work_record(work_attributes, uuid)

          # Create sipity record
          workflow = Sipity::Workflow.joins(:permission_template)
                                     .where(permission_templates: { source_id: new_work.admin_set_id }, active: true)
          workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
          MigrationHelper.retry_operation('creating sipity entity for work') do
            Sipity::Entity.create!(proxy_for_global_id: new_work.to_global_id.to_s,
                                   workflow: workflow.first,
                                   workflow_state: workflow_state.first)
          end

          # Record old and new ids for works
          add_id_mapping(uuid, new_work)

          puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} Number of files: #{work_attributes['contained_files'].count.to_s unless work_attributes['contained_files'].blank?}"

          # Save list of child filesets
          new_work.ordered_members = Array.new

          # Create children
          if !work_attributes['cdr_model_type'].blank? &&
              (work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork')
            unless work_attributes['contained_files'].blank?
              # attach children as filesets
              work_attributes['contained_files'].each do |file|
                metadata_file = @object_hash[MigrationHelper.get_uuid_from_path(file)] || ''
                if File.file?(metadata_file)
                  parsed_file_data = Migrate::Services::MetadataParser.new(metadata_file,
                                                                           @object_hash,
                                                                           @binary_hash,
                                                                           @deposit_record_hash,
                                                                           collection_uuids,
                                                                           @depositor,
                                                                           @collection_name,
                                                                           @admin_set_id).parse

                  file_work_attributes = (parsed_file_data.blank? ? {} : parsed_file_data)
                  file_work_attributes['title'] = file_work_attributes['dc_title'] || file_work_attributes['title'] || @binary_hash[MigrationHelper.get_uuid_from_path(file)].split('/').last || work_attributes['title']

                  # If a child is explicitly private, then ignore inherited permissions
                  fileset_attrs = if file_work_attributes['is_private']
                                    file_record(file_work_attributes)
                                  else
                                    # Inheriting permissions if not explicitly marked private (inherit=false explicitly marks private)
                                    file_record(work_attributes.merge(file_work_attributes))
                                  end

                  # If the parent work is not visible, then its children must be private
                  if work_attributes['visibility'] == vis_private
                    file_work_attributes['visibility'] = vis_private
                    fileset_attrs['visibility'] = vis_private
                  # Inherit authenticated visibility unless a more restrictive policy is present
                  elsif work_attributes['visibility'] == vis_authenticated && file_work_attributes['visibility'] != vis_private
                    file_work_attributes['visibility'] = vis_authenticated
                    fileset_attrs['visibility'] = vis_authenticated
                  end

                  # Give same permissions to fileset and work
                  fileset_attrs['permissions_attributes'] = group_permissions

                  fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: @binary_hash[MigrationHelper.get_uuid_from_path(file)])

                  new_work.ordered_members << fileset

                  # Record old and new ids for works
                  add_file_id_mapping(file, new_work, fileset)
                else
                  puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} missing file: #{file}"
                end
              end
            end
          else
            # use same metadata for work and fileset
            unless work_attributes['contained_files'].blank?
              work_attributes['contained_files'].each do |file|
                binary_file = @binary_hash[MigrationHelper.get_uuid_from_path(file)]
                work_attributes['title'] = work_attributes['dc_title'] || work_attributes['title']
                work_attributes['label'] = work_attributes['dc_title'] || work_attributes['title']
                fileset_attrs = file_record(work_attributes)
                # Give same permissions to fileset and work
                fileset_attrs['permissions_attributes'] = group_permissions
                fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: binary_file)

                new_work.ordered_members << fileset

                # Record old and new ids for works
                add_file_id_mapping(file, new_work, fileset)
              end
            end
          end

          # Attach premis files
          unless work_attributes['premis_files'].blank?
            work_attributes['premis_files'].each_with_index do |file, index|
              premis_file = @premis_hash[MigrationHelper.get_uuid_from_path(file)] || ''
              if File.file?(premis_file)
                fileset_attrs = { 'title' => ["PREMIS_Events_Metadata_#{index}_#{uuid}.txt"],
                                  'visibility' => vis_private,
                                  'permissions_attributes' => group_permissions }
                fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: premis_file)

                new_work.ordered_members << fileset
              else
                puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} missing premis file: #{file}"
              end
            end
          end

          # Attach metadata files
          if File.file?(file_path)
            fileset_attrs = { 'title' => ["original_metadata_file_#{uuid}.xml"],
                              'visibility' => vis_private,
                              'permissions_attributes' => group_permissions }
            fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: file_path)

            new_work.ordered_members << fileset
          else # This should never happen
            puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} missing metadata file: #{file_path}"
          end

          # Record that this object was migrated
          @object_progress.add_entry(uuid)
          end_time = Time.now
          puts "[#{end_time.to_s}] #{uuid},#{new_work.id} Completed migration in #{end_time - start_time} seconds"
        end

        attach_children unless @child_work_type.blank?
        STDOUT.flush
      end

      def create_fileset(parent: nil, resource: nil, file: nil)
        # save group permissions info and remove from fileset attribute hash since it is not a valid fileset attribute
        group_permissions = resource['permissions_attributes']
        resource.delete('permissions_attributes')

        resource['title'].map! { |title| title.gsub('/', '_') }
        file_set = nil
        MigrationHelper.retry_operation('creating fileset') do
          file_set = FileSet.create(resource)
        end

        # Give same permissions to fileset and work
        file_set.permissions_attributes = group_permissions

        actor = Hyrax::Actors::FileSetActor.new(file_set, @depositor)
        actor.create_metadata(resource)

        filename = Array(resource['title']).first
        extension = filename.match(/\./) ? filename.split('.').last : nil
        omission = (extension.blank? || MimeTypeService.valid?(extension).blank?) ? '' : ".#{extension}"

        renamed_file = if filename.bytesize > 255
                         "#{@tmp_file_location}/#{parent.id}/#{filename.mb_chars.limit(255 - omission.bytesize).to_s}#{omission}"
                       else
                         "#{@tmp_file_location}/#{parent.id}/#{filename}"
                       end
        FileUtils.mkpath("#{@tmp_file_location}/#{parent.id}")
        FileUtils.cp(file, renamed_file)

        MigrationHelper.retry_operation('creating fileset') do
          actor.create_content(Hyrax::UploadedFile.create(file: File.open(renamed_file), user: @depositor))
        end

        MigrationHelper.retry_operation('creating fileset') do
          actor.attach_to_work(parent, resource)
        end

        File.delete(renamed_file) if File.exist?(renamed_file)
        FileUtils.rm_rf("#{@tmp_file_location}/#{parent.id}")

        file_set
      end

      private
      def work_record(work_attributes, uuid)
        # save group permissions info and remove from work attribute hash since it is not a valid work attribute
        group_permissions = work_attributes['permissions_attributes']
        work_attributes.delete('permissions_attributes')

        is_child_work = !@child_work_type.blank? && !work_attributes['cdr_model_type'].blank? &&
            !(work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork')

        resource = if is_child_work
                     @child_work_type.singularize.classify.constantize.new
                   else
                     @work_type.singularize.classify.constantize.new
                   end
        resource.depositor = @depositor.uid

        # escape '\'
        work_attributes.each do |k, v|
          if v.is_a? Array
            work_attributes[k] = v.map { |val| val.gsub(/\\/, '\\\\\\') if val.is_a? String }
          elsif v.is_a? String
            work_attributes[k] = v.gsub(/\\/, '\\\\\\')
          end
        end

        resource = MigrationHelper.check_enumeration(work_attributes, resource, uuid)

        resource.visibility = work_attributes['visibility']
        unless work_attributes['embargo_release_date'].blank?
          resource.embargo_release_date = work_attributes['embargo_release_date']
          resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
          resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
        end

        # Override the admin set id for child works
        resource.admin_set_id = if is_child_work && !@child_admin_set_id.blank?
                                  @child_admin_set_id
                                else
                                  work_attributes['admin_set_id']
                                end

        resource.member_of_collections = work_attributes['member_of_collections'] if !@config['collection_name'].blank? && !work_attributes['member_of_collections'].first.blank?

        save_time = Time.now
        puts "[#{save_time.to_s}] #{uuid} saving work"
        MigrationHelper.retry_operation('creating work') do
          resource.save!
        end

        # Add group permissions
        resource.update permissions_attributes: group_permissions

        # Logging data that has been deduplicated upon saving
        deduped = {}
        resource.attributes.except('advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors',
                                   'researchers', 'reviewers', 'translators', 'based_near').each do |k, v|
          deduped[k] = work_attributes[k] if (Array(work_attributes[k]).sort != Array(v).sort && !work_attributes[k].blank?)
        end
        puts "#{Time.now.to_s}] #{uuid},#{resource.id} deduped data: #{deduped}" unless deduped.blank?

        puts "[#{Time.now.to_s}] #{uuid},#{resource.id} saved new work in #{Time.now - save_time} seconds"

        resource
      end

      # FileSets can include any metadata listed in BasicMetadata file
      def file_record(attrs)
        file_set = FileSet.new
        file_attributes = Hash.new
        # Singularize non-enumerable attributes
        attrs.each do |k, v|
          if file_set.attributes.keys.member?(k.to_s)
            file_attributes[k] = if !file_set.attributes[k.to_s].respond_to?(:each) && attrs[k].respond_to?(:each)
                                   v.first
                                 else
                                   v
                                 end
          end
        end
        file_attributes[:date_created] = attrs['date_created']
        file_attributes[:visibility] = attrs['visibility']
        unless attrs['embargo_release_date'].blank?
          file_attributes[:embargo_release_date] = attrs['embargo_release_date']
          file_attributes[:visibility_during_embargo] = attrs['visibility_during_embargo']
          file_attributes[:visibility_after_embargo] = attrs['visibility_after_embargo']
        end

        file_attributes
      end

      def attach_children
        # Load mapping of old uuids to new hyrax ids
        uuid_to_id = Hash[@id_mapper.mappings.map { |row| [row[0], row[1].split('/')[-1]] unless row[1].match?('file_sets') }.compact]
        # Load mapping of parents to children
        parent_hash = Hash[@parent_child_mapper.mappings.map { |row| [row[0], row[1].split('|')] }]
        # Create or resume log of children attached
        attached_mapper = Migrate::Services::ProgressTracker.new(File.join(@output_dir, 'attached_progress.log'))
        # Load the mapping of children to parent that have been attached, in case we are resuming
        already_attached = attached_mapper.completed_set

        attach_time = Time.now
        puts "[#{attach_time.to_s}] attaching children to parents"
        parent_hash.each do |parent_id, children|
          attach_to_parent_time = Time.now

          hyrax_id = uuid_to_id[parent_id]
          parent = @work_type.singularize.classify.constantize.find(hyrax_id)
          parent_changed = false

          children.each do |child|
            next if already_attached.include?(child)

            # If the child is in the uuid_to_id mapping, it is a child work and must be attached to the parent
            child_id = uuid_to_id[child]
            if child_id
              parent.ordered_members << ActiveFedora::Base.find(child_id)
              parent.members << ActiveFedora::Base.find(child_id)
              parent_changed = true
            end
          end
          # Persist the parent with its updated list of children if any were added
          if parent_changed
            MigrationHelper.retry_operation('attaching children') do
              parent.save!
            end
            puts "Attached children to parent #{hyrax_id} in #{Time.now - attach_to_parent_time} seconds"
            # Log that the children were attached
            children.each do |child|
              attached_mapper.add_entry(child)
            end
          else
            puts "No additional children attached to parent #{hyrax_id}"
          end
        end
        puts "[#{Time.now.to_s}] finished attaching children in #{Time.now - attach_time} seconds"
      end

      # Add a mapping from old uuid to the new work
      def add_id_mapping(uuid, new_work)
        # Pluralize the worktype
        work_type = new_work.class.to_s.underscore
        work_type = if work_type == 'honors_thesis'
                      'honors_theses'
                    else
                      work_type + 's'
                    end
        new_path = "#{work_type}/#{new_work.id}"

        @id_mapper.add_row(uuid, new_path)
      end

      # Add a mapping from old uuid for a file, to its new path within a fileset
      def add_file_id_mapping(file, new_work, fileset)
        new_id = 'parent/' + new_work.id + '/file_sets/' + fileset.id
        @id_mapper.add_row(MigrationHelper.get_uuid_from_path(file), new_id)
      end
    end
  end
end
