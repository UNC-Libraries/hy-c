module Migrate
  module Services
    class ChildWorkParser

      def initialize(object_hash, config, output_dir)
        @object_hash = object_hash
        @collection_uuids = MigrationHelper.get_collection_uuids(config['collection_list'])


        # Store parent-child relationships
        @parent_child_mapper = Migrate::Services::IdMapper.new(File.join(output_dir, 'parent_child.csv'), 'parent', 'children')
        # Progress tracker for objects migrated
        @object_progress = Migrate::Services::ProgressTracker.new(File.join(output_dir, 'object_progress.log'))
      end

      def find_children
        start_time = Time.now
        # build parent hash
        puts "[#{Time.now.to_s}] Building parent-child relationships"

        @collection_uuids.each do |uuid|
          metadata = Nokogiri::XML(File.open(@object_hash[uuid]))

          child_works = Array.new

          # RDF information
          cdr_model_type = ''
          rdf_version = metadata.xpath("//rdf:RDF", MigrationConstants::NS).last
          if rdf_version
            # Check if aggregate work
            if rdf_version.to_s.match(/hasModel/)
              cdr_model_type = rdf_version.xpath('rdf:Description/*[local-name() = "hasModel"]/@rdf:resource', MigrationConstants::NS).map(&:text)
            end

            # Create lists of attached files and children
            if rdf_version.to_s.match(/resource/)
              contained_objects = rdf_version.xpath("rdf:Description/*[not(local-name()='originalDeposit') and not(local-name() = 'defaultWebObject') and contains(@rdf:resource, 'uuid')]", MigrationConstants::NS)
              contained_objects.each do |contained_file|
                tmp_uuid = MigrationHelper.get_uuid_from_path(contained_file.to_s)
                if cdr_model_type.include? 'info:fedora/cdr-model:AggregateWork' && !@object_hash[tmp_uuid].blank? && tmp_uuid != uuid
                  child_works << tmp_uuid
                end
              end

              representative = rdf_version.xpath('rdf:Description/*[local-name() = "defaultWebObject"]/@rdf:resource', MigrationConstants::NS).to_s.split('/')[1]
              if representative
                representative_uuid = MigrationHelper.get_uuid_from_path(representative)
                child_works -= [representative_uuid]

                # Record that primary object was completed
                @object_progress.add_entry(representative_uuid)
              end
            end
          end

          # store mapping of parent to children
          store_children(uuid, child_works)
        end

        puts "[#{Time.now.to_s}] Completed building parent-child relationships in #{Time.now-start_time} seconds"
      end


      private

        # Store the parent to children mapping for a work
        def store_children(uuid, child_works)
          if child_works.blank?
            return
          end
          @parent_child_mapper.add_row(uuid, child_works.join('|'))
        end
    end
  end
end
