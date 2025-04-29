# frozen_string_literal: true
module Tasks
  class PubmedIngestService
    include Tasks::IngestHelper
    def attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
      # Create a work object using the provided work_hash
      model_class = work_hash[:work_type].constantize
      work = model_class.find(work_hash[:work_id])
      depositor =  User.find_by(uid: depositor_onyen)
      file = attach_pdf_to_work(work, file_path, depositor, visibility)
      admin_set = ::AdminSet.where(id: work_hash[:admin_set_id]).first
      file.update(permissions_attributes: group_permissions(admin_set))
      file
    end

    def create_new_record(work_hash, file_path, depositor_onyen, visibility)
      representative_id = work_hash[:pmcid] || work_hash[:pmid]
      db = representative_id.start_with?('PMC') ? 'pmc' : 'pubmed'
      # API Prefers batches of 200

      request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=#{db}&id=#{representative_id}&retmode=xml"
      res = HTTParty.get(request_url)

      # WIP: Remove Later
      puts "WIP LOG: #{request_url} #{res.code} #{res.body.truncate(500)}"

      if res.code != 200
        Rails.logger.error("Failed to fetch metadata for #{representative_id}: #{res.code} - #{res.message}")
        return nil
      else
        article = Article.new
        # attach_metadata_to_article(article, res.body)
        article
      end
    end

    def batch_retrieve_metadata(work_hash_array)
      retrieved_metadata = []
      # Only retrieve metadata for PDFs with no matching work in the CDR
      work_hash_array = work_hash_array.select do |work_hash|
        work_hash['pdf_attached'] == 'Skipped: No CDR URL'
      end
      # Prep for retrieving metadata from different endpoints
      works_with_pmids = work_hash_array.select { |work_hash| work_hash['pmid'].present? }
      works_with_pmcids = work_hash_array.select { |work_hash| works_with_pmids.exclude?(work_hash) && work_hash['pmcid'].present? }
      # request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=#{db}&id=#{representative_id}&retmode=xml"
      # res = HTTParty.get(request_url)

      short = 0
      works_with_pmcids.each_slice(200) do |batch|
        # WIP: Remove Later
        break if short >= 200
        ids = batch.map { |work| work['pmcid'].sub(/^PMC/, '') } # Remove "PMC" prefix if present
        request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pmc&id=#{ids.join(',')}&retmode=xml&tool=YourToolName&email=your@email.com"
        res = HTTParty.get(request_url)
        # WIP: Remove Later
        if short == 0
          puts "WIP LOG BATCH 1: #{request_url} #{res.code} #{res.body.truncate(500)}"
        end

        # retrieved_metadata << res
        short += ids.length
      end

      short = 0
      works_with_pmids.each_slice(200) do |batch|
       # WIP: Remove Later
        break if short >= 200
        ids = batch.map { |work| work['pmid'] }
        request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=#{ids.join(',')}&retmode=xml&tool=YourToolName&email=your@email.com"
        res = HTTParty.get(request_url)

        # WIP: Remove Later
        if short == 0
          puts "WIP LOG BATCH 2: #{request_url} #{res.code} #{res.body.truncate(500)}"
        end

        # retrieved_metadata << res
        short += ids.length
      end

      # work_hash_array.each do |work_hash|
        # end
      retrieved_metadata
    end


    def set_basic_attributes(work_hash, file_path, depositor_onyen, visibility)
      # Set the basic attributes for the work
      work = work_hash[:work_type].constantize.new(work_hash)
      work.depositor = depositor_onyen
      work.admin_set_id = work_hash[:admin_set_id]
      work.visibility = visibility
      work.save!
      attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
    end
end
end
