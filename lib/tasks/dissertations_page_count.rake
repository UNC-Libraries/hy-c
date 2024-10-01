# lib/tasks/dissertations_page_count.rake

namespace :dissertations do
    desc "Calculate total page counts for dissertations"
    
    task :page_count, [:year] => :environment do |task, args|
      require 'rdf'
      require 'rdf/ntriples'
      require 'open-uri'
      year = args[:year]
      
      # Method to fetch all dissertations by paginating through Solr results
      def fetch_all_dissertations
        start = 0
        rows = 1000 
        all_processed_dissertations = []

        loop do
          response = ActiveFedora::SolrService.get('admin_set_tesim:"Dissertations"', start: start, rows: rows)
          processed_dissertations = response['response']['docs'].map { |doc| process_dissertation(doc) }
          all_processed_dissertations.concat(processed_dissertations)

          # Stop when no more results are returned
          break if processed_dissertations.empty? || processed_dissertations.length < rows 
          start += rows
        end

        all_processed_dissertations
      end

      def process_dissertation(dissertation)
        res = {}
        res[:id] = dissertation['id']
        res[:title] = dissertation['title_tesim']&.first
        # Associating page count with the dissertation instead of the fileset
        res[:page_count] = total_page_count_for_fileset_ids(dissertation['file_set_ids_ssim'])
        return res
      end

      def total_page_count_for_fileset_ids(fileset_ids)
        Rails.logger.info("Total page count for fileset ids: #{fileset_ids}")
        sum = 0
        fileset_ids.each do |fileset_id|
          fileset_object = ActiveFedora::Base.find(fileset_id)
          # WIP: Log the full object inspection
          Rails.logger.info("Inspecting ActiveFedora::Base.find(#{fileset_id}): #{fileset_object.inspect}")
          # Log the available attributes (if they exist)
          if fileset_object.respond_to?(:attributes)
            Rails.logger.info("Attributes: #{fileset_object.attributes}")
          end

          # Check if the object has a page_count method
          if fileset_object.respond_to?(:page_count)
            page_count = fileset_object.page_count.to_s
            Rails.logger.info("Page count for #{fileset_id}: #{page_count}")
            # sum += page_count
          else
            Rails.logger.warn("No page_count method found for #{fileset_id}")
          end
        end
        return sum
      end

      # # Method to get the total page count for all dissertations in admin set
      # def total_page_count(year)
      #   # Print solr production url environment variable
      #   # dissertations = ActiveFedora::SolrService.get("admin_set_tesim:Dissertations")['response']['docs'].first || {}
      #   dissertations = ActiveFedora::SolrService.get('admin_set_tesim:"Dissertations"', rows: 999)
      #   Rails.logger.info("Dissertations: #{dissertations.inspect}")
      #   # Inspect the response
      #   dissertations['response']['docs'].each_with_index do |doc,index|
      #     Rails.logger.info("Inspect doc #{index}: #{doc.inspect}")
      #   end
      #   # 0.upto(4) do |i|
      #   #     Rails.logger.info("Inspect Dissertation #{i}: #{works_in_admin_set[i].inspect}")
      #   # end
      #   total_pages = 0
      #   total_pages
      # end
  
      total_pages_all = fetch_all_dissertations
    #   total_pages_2023 = total_page_count_for_year(admin_set_id, 2023)
  
    #   puts "Total page count for all dissertations: #{total_pages_all}"
    #   puts "Total page count for 2023 dissertations: #{total_pages_2023}"
    end
  end
  