module Migrate
  module Services
    require 'tasks/migrate/services/id_mapper'
    require 'tasks/migrate/services/metadata_parser'

    class IngestService

      def initialize(config, object_hash, binary_hash, premis_hash, mapping_file, depositor)
        @collection_ids_file = config['collection_list']
        @object_hash = object_hash
        @binary_hash = binary_hash
        @premis_hash = premis_hash
        @work_type = config['work_type']
        @admin_set = config['admin_set']
        @child_work_type = config['child_work_type']
        @mapping_file = mapping_file
        @collection_name = config['collection_name']
        @depositor = depositor
        @tmp_file_location = config['tmp_file_location']
      end

      def ingest_records
        # Create file and hash mapping new and old ids
        id_mapper = Migrate::Services::IdMapper.new(@mapping_file)
        @mappings = Hash.new

        # Store parent-child relationships
        @parent_hash = Hash.new

        # get array of record uuids
        collection_uuids = get_collection_uuids

        puts "Object count:  #{collection_uuids.count.to_s}"

        # get metadata for each record
        collection_uuids.each do |uuid|
          start_time = Time.now
          puts "[#{start_time.to_s}] Start migration of #{uuid}"
          parsed_data = Migrate::Services::MetadataParser.new(@object_hash[uuid],
                                                          @object_hash,
                                                          @binary_hash,
                                                          collection_uuids,
                                                          @collection_name,
                                                          @depositor,
                                                          @admin_set).parse
          work_attributes = parsed_data[:work_attributes]
          @parent_hash[uuid] = parsed_data[:child_works] if !parsed_data[:child_works].blank?

          # Create new work record and save
          new_work = work_record(work_attributes)
          new_work.save!

          # Record old and new ids for works
          id_mapper.add_row([uuid, new_work.id])
          @mappings[uuid] = new_work.id

          puts "Number of files: #{work_attributes['contained_files'].count.to_s if !work_attributes['contained_files'].blank?}"

          # Save list of child filesets
          ordered_members = Array.new

          # Attach premis files
          if !work_attributes['premis_files'].blank?
            work_attributes['premis_files'].each_with_index do |file, index|
              premis_file = @premis_hash[get_uuid_from_path(file)]
              fileset_attrs = { 'title' => ["PREMIS_Events_Metadata_#{index}.txt"],
                                'visibility' => Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }
              fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: premis_file)

              ordered_members << fileset
            end
          end

          # Create children
          if !work_attributes['cdr_model_type'].blank? &&
              (work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork')
            # attach children as filesets
            work_attributes['contained_files'].each do |file|
              metadata_file = @object_hash[get_uuid_from_path(file)]
              parsed_file_data = Migrate::Services::MetadataParser.new(metadata_file,
                                                                   @object_hash,
                                                                   @binary_hash,
                                                                   collection_uuids,
                                                                   @collection_name,
                                                                   @depositor,
                                                                   @admin_set).parse

              file_work_attributes = (parsed_file_data[:work_attributes].blank? ? {} : parsed_file_data[:work_attributes])
              fileset_attrs = file_record(work_attributes.merge(file_work_attributes))

              fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: @binary_hash[get_uuid_from_path(file)])

              # Record old and new ids for works
              id_mapper.add_row([get_uuid_from_path(file), fileset.id])

              ordered_members << fileset
            end
          else
            # use same metadata for work and fileset
            if !work_attributes['contained_files'].blank?
              work_attributes['contained_files'].each do |file|
                binary_file = @binary_hash[get_uuid_from_path(file)]
                work_attributes['title'] = work_attributes['dc_title']
                work_attributes['label'] = work_attributes['dc_title']
                fileset_attrs = file_record(work_attributes)
                fileset = create_fileset(parent: new_work, resource: fileset_attrs, file: binary_file)

                # Record old and new ids for works
                id_mapper.add_row([get_uuid_from_path(file), fileset.id])

                ordered_members << fileset
              end
            end
          end

          new_work.ordered_members = ordered_members
          end_time = Time.now
          puts "[#{end_time.to_s}] Completed migration of #{uuid} in #{end_time-start_time} seconds"
        end

        if !@child_work_type.blank?
          attach_children
        end
      end

      def create_fileset(parent: nil, resource: nil, file: nil)
        file_set = FileSet.create(resource)
        actor = Hyrax::Actors::FileSetActor.new(file_set, @depositor)
        actor.create_metadata(resource)

        if file.match('DATA_FILE')
          renamed_file = "#{@tmp_file_location}/#{parent.id}/#{Array(resource['title']).first}"
          FileUtils.mkpath("#{@tmp_file_location}/#{parent.id}")
          FileUtils.cp(file, renamed_file)
        else
          renamed_file = file
        end

        actor.create_content(Hyrax::UploadedFile.create(file: File.open(renamed_file), user: @depositor))
        actor.attach_to_work(parent, resource)

        File.delete(renamed_file) if File.exist?(renamed_file)

        file_set
      end


      private

        def get_collection_uuids
          collection_uuids = Array.new
          CSV.open(@collection_ids_file) do |file|
            file.each do |line|
              if !line.blank? && !get_uuid_from_path(line[0].strip).blank?
                collection_uuids.append(get_uuid_from_path(line[0].strip))
              end
            end
          end

          collection_uuids
        end

        def get_uuid_from_path(path)
          path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/) || ''
        end

        def work_record(work_attributes)
          if !@child_work_type.blank? && !work_attributes['cdr_model_type'].blank? &&
              !(work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork')
            resource = @child_work_type.singularize.classify.constantize.new
          else
            resource = @work_type.singularize.classify.constantize.new
          end
          resource.depositor = @depositor.uid
          resource.save

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
              work_attributes.delete(k.split('s_')[0]+'_display')
              work_attributes.delete(k)
            end
          end
          resource.attributes = work_attributes.reject{|k,v| !resource.attributes.keys.member?(k.to_s) unless k.ends_with? '_attributes'}

          resource.visibility = work_attributes['visibility']
          unless work_attributes['embargo_release_date'].blank?
            resource.embargo_release_date = work_attributes['embargo_release_date']
            resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
            resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
          end
          resource.admin_set_id = work_attributes['admin_set_id']
          if !@collection_name.blank? && !work_attributes['member_of_collections'].first.blank?
            resource.member_of_collections = work_attributes['member_of_collections']
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
          @parent_hash.each do |parent_id, children|
            hyrax_id = @mappings[parent_id]
            parent = @work_type.singularize.classify.constantize.find(hyrax_id)
            children.each do |child|
              if @mappings[child]
                parent.ordered_members << ActiveFedora::Base.find(@mappings[child])
                parent.members << ActiveFedora::Base.find(@mappings[child])
              end
            end
            parent.save!
          end
        end
    end
  end
end
