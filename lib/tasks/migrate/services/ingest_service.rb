module Migrate
  module Services
    require 'tasks/migrate/services/id_mapper'
    require 'tasks/migrate/services/metadata_parser'
    require 'tasks/migration_helper'

    class IngestService

      def initialize(config, object_hash, binary_hash, premis_hash, deposit_record_hash, mapping_file, depositor)
        @collection_ids_file = config['collection_list']
        @object_hash = object_hash
        @binary_hash = binary_hash
        @premis_hash = premis_hash
        @deposit_record_hash = deposit_record_hash
        @work_type = config['work_type']
        @child_work_type = config['child_work_type']
        @mapping_file = mapping_file
        @depositor = depositor
        @tmp_file_location = config['tmp_file_location']
        @config = config
      end

      def ingest_records
        # Create file and hash mapping new and old ids
        id_mapper = Migrate::Services::IdMapper.new(@mapping_file)
        @mappings = Hash.new

        # Store parent-child relationships
        @parent_hash = Hash.new

        # get array of record uuids
        collection_uuids = MigrationHelper.get_collection_uuids(@collection_ids_file)

        puts "[#{Time.now.to_s}] Object count:  #{collection_uuids.count.to_s}"

        # get metadata for each record
        collection_uuids.each do |uuid|
          start_time = Time.now
          puts "[#{start_time.to_s}] #{uuid} Start migration"
          parsed_data = Migrate::Services::MetadataParser.new(@object_hash[uuid],
                                                              @object_hash,
                                                              @binary_hash,
                                                              @deposit_record_hash,
                                                              collection_uuids,
                                                              @depositor,
                                                              @config).parse
          puts "[#{Time.now.to_s}] #{uuid} metadata parsed in #{Time.now-start_time} seconds"
          work_attributes = parsed_data[:work_attributes]
          @parent_hash[uuid] = parsed_data[:child_works] if !parsed_data[:child_works].blank?

          # Create new work record and save
          new_work = work_record(work_attributes, uuid)
          save_time = Time.now
          puts "[#{save_time.to_s}] #{uuid} saving work"
          MigrationHelper.retry_operation do
            new_work.save!
          end

          puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} saved new work in #{Time.now-save_time} seconds"

          # Record old and new ids for works
          id_mapper.add_row([uuid, new_work.class.to_s.underscore+'s/'+new_work.id])
          @mappings[uuid] = new_work.id

          puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} Number of files: #{work_attributes['contained_files'].count.to_s if !work_attributes['contained_files'].blank?}"

          # Save list of child filesets
          ordered_members = Array.new

          # Create children
          if !work_attributes['cdr_model_type'].blank? &&
              (work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork')
            if !work_attributes['contained_files'].blank?
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
                                                                           @config).parse

                  file_work_attributes = (parsed_file_data[:work_attributes].blank? ? {} : parsed_file_data[:work_attributes])
                  fileset_attrs = file_record(work_attributes.merge(file_work_attributes))

                  fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: @binary_hash[MigrationHelper.get_uuid_from_path(file)])

                  # Record old and new ids for works
                  id_mapper.add_row([MigrationHelper.get_uuid_from_path(file), 'parent/'+new_work.id+'/file_sets/'+fileset.id])

                  ordered_members << fileset
                else
                  puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} missing file: #{file}"
                end
              end
            end
          else
            # use same metadata for work and fileset
            if !work_attributes['contained_files'].blank?
              work_attributes['contained_files'].each do |file|
                binary_file = @binary_hash[MigrationHelper.get_uuid_from_path(file)]
                work_attributes['title'] = work_attributes['dc_title']
                work_attributes['label'] = work_attributes['dc_title']
                fileset_attrs = file_record(work_attributes)
                fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: binary_file)

                # Record old and new ids for works
                id_mapper.add_row([MigrationHelper.get_uuid_from_path(file), 'parent/'+new_work.id+'/file_sets/'+fileset.id])

                ordered_members << fileset
              end
            end
          end

          # Attach premis files
          if !work_attributes['premis_files'].blank?
            work_attributes['premis_files'].each_with_index do |file, index|
              premis_file = @premis_hash[MigrationHelper.get_uuid_from_path(file)] || ''
              if File.file?(premis_file)
                fileset_attrs = { 'title' => ["PREMIS_Events_Metadata_#{index}.txt"],
                                  'visibility' => Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }
                fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: premis_file)

                ordered_members << fileset
              else
                puts "[#{Time.now.to_s}] #{uuid},#{new_work.id} missing premis file: #{file}"
              end
            end
          end

          new_work.ordered_members = ordered_members
          end_time = Time.now
          puts "[#{end_time.to_s}] #{uuid},#{new_work.id} Completed migration in #{end_time-start_time} seconds"
        end

        if !@child_work_type.blank?
          attach_children
        end
        STDOUT.sync = true
        STDOUT.flush
      end

      def create_fileset(parent: nil, resource: nil, file: nil)
        file_set = nil
        MigrationHelper.retry_operation('creating fileset') do
          file_set = FileSet.create(resource)
        end

        actor = Hyrax::Actors::FileSetActor.new(file_set, @depositor)
        actor.create_metadata(resource)

        renamed_file = "#{@tmp_file_location}/#{parent.id}/#{Array(resource['title']).first}"
        FileUtils.mkpath("#{@tmp_file_location}/#{parent.id}")
        FileUtils.cp(file, renamed_file)

        MigrationHelper.retry_operation('creating fileset') do
          actor.create_content(Hyrax::UploadedFile.create(file: File.open(renamed_file), user: @depositor))
        end
        
        MigrationHelper.retry_operation('creating fileset') do
          actor.attach_to_work(parent, resource)
        end

        File.delete(renamed_file) if File.exist?(renamed_file)

        file_set
      end


      private
        def work_record(work_attributes, uuid)
          if !@child_work_type.blank? && !work_attributes['cdr_model_type'].blank? &&
              !(work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork')
            resource = @child_work_type.singularize.classify.constantize.new
          else
            resource = @work_type.singularize.classify.constantize.new
          end
          resource.depositor = @depositor.uid
#          resource.save

          # Singularize non-enumerable attributes
          work_attributes.each do |k,v|
            if resource.attributes.keys.member?(k.to_s) && !resource.attributes[k.to_s].respond_to?(:each) && work_attributes[k].respond_to?(:each)
              work_attributes[k] = v.first
            else
              work_attributes[k] = v
            end
          end

          # Only keep attributes which apply to the given work type
          work_attributes.select {|k,v| k.ends_with? '_attributes'}.each do |k,v|
            if !resource.respond_to?(k.to_s+'=')
              # Log non-blank person data which is not saved
              puts "[#{Time.now.to_s}] #{uuid} missing: #{k}=>#{v}"
              work_attributes.delete(k.split('s_')[0]+'_display')
              work_attributes.delete(k)
            end
          end

          resource.attributes = work_attributes.reject{|k,v| !resource.attributes.keys.member?(k.to_s) unless k.ends_with? '_attributes'}

          # Log other non-blank data which is not saved
          missing = work_attributes.except(*resource.attributes.keys, 'contained_files', 'cdr_model_type', 'visibility',
                                           'creators_attributes', 'contributors_attributes', 'advisors_attributes',
                                           'arrangers_attributes', 'composers_attributes', 'funders_attributes',
                                           'project_directors_attributes', 'researchers_attributes', 'reviewers_attributes',
                                           'translators_attributes', 'dc_title', 'premis_files', 'embargo_release_date',
                                           'visibility_during_embargo', 'visibility_after_embargo', 'visibility',
                                           'member_of_collections')
          if !missing.blank?
            puts "[#{Time.now.to_s}] #{uuid} missing: #{missing}"
          end

          resource.visibility = work_attributes['visibility']
          unless work_attributes['embargo_release_date'].blank?
            resource.embargo_release_date = work_attributes['embargo_release_date']
            resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
            resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
          end
          resource.admin_set_id = work_attributes['admin_set_id']
          if !@config['collection_name'].blank? && !work_attributes['member_of_collections'].first.blank?
            resource.member_of_collections = work_attributes['member_of_collections']
          end

          MigrationHelper.retry_operation('creating child work') do
            resource.save!
          end

          resource
        end

        # FileSets can include any metadata listed in BasicMetadata file
        def file_record(work_attributes)
          file_set = FileSet.new
          file_attributes = Hash.new
          # Singularize non-enumerable attributes
          work_attributes.each do |k,v|
            if file_set.attributes.keys.member?(k.to_s)
              if !file_set.attributes[k.to_s].respond_to?(:each) && work_attributes[k].respond_to?(:each)
                file_attributes[k] = v.first
              else
                file_attributes[k] = v
              end
            end
          end
          file_attributes[:visibility] = work_attributes['visibility']
          unless work_attributes['embargo_release_date'].blank?
            file_attributes[:embargo_release_date] = work_attributes['embargo_release_date']
            file_attributes[:visibility_during_embargo] = work_attributes['visibility_during_embargo']
            file_attributes[:visibility_after_embargo] = work_attributes['visibility_after_embargo']
          end

          file_attributes
        end


        def attach_children
          attach_time = Time.now
          puts "[#{attach_time.to_s}] attaching children to parents"
          @parent_hash.each do |parent_id, children|
            hyrax_id = @mappings[parent_id]
            parent = @work_type.singularize.classify.constantize.find(hyrax_id)
            children.each do |child|
              if @mappings[child]
                parent.ordered_members << ActiveFedora::Base.find(@mappings[child])
                parent.members << ActiveFedora::Base.find(@mappings[child])
              end
            end
            MigrationHelper.retry_operation('attaching children') do
              parent.save!
            end
          end
          puts "[#{Time.now.to_s}] finished attaching children in #{Time.now-attach_time} seconds"
        end
    end
  end
end
