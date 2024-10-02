# frozen_string_literal: true
# lib/tasks/dissertations_page_count.rake

namespace :dissertations do
  desc 'Calculate total page counts for dissertations'

  task :page_count, [:year] => :environment do |task, args|
    require 'rdf'
    require 'rdf/ntriples'
    require 'open-uri'
    require 'csv'
    year = args[:year]

    # Method to fetch all dissertations by paginating through Solr results
    def fetch_all_dissertations(year = nil)
      start = 0
      rows = 1000
      all_processed_dissertations = []

      loop do
        query_string = year ? "admin_set_tesim:\"Dissertations\" AND year_tesim:\"#{year}\"" : 'admin_set_tesim:"Dissertations"'
        response = ActiveFedora::SolrService.get(query_string, start: start, rows: rows)
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
      res[:dissertation_id] = dissertation['id']
      res[:title] = dissertation['title_tesim']&.first
      # Associating page count with the dissertation instead of the fileset
      # dissertation['file_set_ids_ssim'] is an array of fileset ids
      res[:page_count] = total_page_count_for_fileset_ids(dissertation['file_set_ids_ssim'])
      return res
    end

    def total_page_count_for_fileset_ids(fileset_ids)
      sum = 0
      fileset_ids.each do |fileset_id|
        fileset_object = ActiveFedora::Base.find(fileset_id)

        # Check if the object has a page_count method
        if fileset_object.respond_to?(:page_count)
          page_count = sum_relation_values(fileset_object.page_count)
          Rails.logger.info("Page count for #{fileset_id}: #{page_count}")
          sum += page_count
        else
          Rails.logger.warn("No page_count method found for #{fileset_id}")
        end
      end
      return sum
    end

    def sum_relation_values(relation)
      if relation.is_a?(ActiveTriples::Relation) || relation.is_a?(Array)
        # Convert each element to an integer and sum them up
        relation.map(&:to_i).sum
      else
        # If it's a single value, just convert it to an integer
        relation.to_i
      end
    end

    def write_to_csv(all_processed_dissertations, year)
      total_pages_all = 0
      path = year ? "/logs/hyc/dissertations_page_count_#{year}.csv" : '/logs/hyc/dissertations_page_count_all.csv'
      # Write the processed dissertations to a CSV file
      CSV.open(path, 'w') do |csv|
        # Write CSV headers
        csv << ['Dissertation ID', 'Title', 'Page Count']

        # Write each dissertation's data to a new row
        all_processed_dissertations.each do |dissertation|
          csv << [dissertation[:dissertation_id], dissertation[:title], dissertation[:page_count]]
          total_pages_all += dissertation[:page_count]
        end
        csv << ['N/A', 'All Total Pages', total_pages_all]
      end
    end

    all_processed_dissertations = fetch_all_dissertations(year)
    write_to_csv(all_processed_dissertations, year)
  end
end
