# lib/tasks/dissertations_page_count.rake

namespace :dissertations do
    desc "Calculate total page counts for dissertations"
    
    task :page_count, [:year] => :environment do |task, args|
      require 'rdf'
      require 'rdf/ntriples'
      require 'open-uri'
      year = args[:year]
  
      # Method to get the total page count for all dissertations in admin set
      def total_page_count(year)
        # Print solr production url environment variable
        # dissertations = ActiveFedora::SolrService.get("admin_set_tesim:Dissertations")['response']['docs'].first || {}
        dissertations = ActiveFedora::SolrService.get('admin_set_tesim:"Dissertations"', rows: 30)
        Rails.logger.info("Dissertations: #{dissertations.inspect}")
        # Inspect the response
        dissertations['response']['docs'].each_with_index do |doc,index|
          Rails.logger.info("Inspect doc #{index}: #{doc.inspect}")
        end
        # 0.upto(4) do |i|
        #     Rails.logger.info("Inspect Dissertation #{i}: #{works_in_admin_set[i].inspect}")
        # end
        total_pages = 0
        total_pages
      end
  
      total_pages_all = total_page_count(year)
    #   total_pages_2023 = total_page_count_for_year(admin_set_id, 2023)
  
    #   puts "Total page count for all dissertations: #{total_pages_all}"
    #   puts "Total page count for 2023 dissertations: #{total_pages_2023}"
    end
  end
  