# frozen_string_literal: true
# Hardcode absolute paths for input and output directories
INPUT_PATH = '/home/dcam/pmc_pdfs/sample'
OUTPUT_PATH = '/home/dcam/pb_match_results.csv'

desc 'Fetch identifiers from a directory, compare against the CDR, and store the results in a CSV'
task fetch_identifiers: :environment do |task, args|
  path = Rails.root.join(INPUT_PATH)
  output_path = Rails.root.join(OUTPUT_PATH)
  file_names = filenames_in_dir(path)
    # Store the file names in a CSV
  store_file_names_and_cdr_data(file_names, output_path)
end

desc 'Attach new PDFs to works'
task :attach_pubmed_pdfs, [:input_csv_path, :input_pdf_dir] => :environment do |task, args|
  return unless valid_args('attach_pubmed_pdfs', args[:input_csv_path], args[:input_pdf_dir])
#   WIP: Implement the PubmedIngestService
#   ingest_service = Tasks::PubmedIngestService.new
  res = {skipped: [], ingested: [], failed: [], time: Time.now, depositor: ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN'], directory: args[:input_pdf_dir]}

#   Retrieve all files within pdf directory
  file_names = filenames_in_dir(args[:input_pdf_dir])

  modified_rows = []
  CSV.foreach(args[:input_csv_path], headers: true) do |row|
    # Set 'pdf_attached' to 'Skipped' if the below conditions are met and categorize the row as skipped
    if hash['cdr_url'].nil? || hash['has_fileset'].present?
      skip_message = hash['cdr_url'].nil? ? 'No CDR URL' : 'File already attached'
      hash['pdf_attached'] = "Skipped: #{skip_message}"
      res[:skipped] << hash
      next
    end
    # WIP: Implement the PubmedIngestService
    row_post_attachment = ingest_service.attach_pdf_to_work(row, args[:input_pdf_dir])
    # Categorize the row depending on the result of the attachment
    modified_rows << row_post_attachment
  end
  ##### Write 'res' to a JSON file #####
  ##### Write 'attached_pdfs_output' to a CSV file #####
end

def filenames_in_dir(directory)
  # Fetch file names from the directory
  # Strip the file extension and remove duplicates
  Dir.entries(directory).select { |f| !File.directory? f }.map { |f| File.basename(f, '.*') }.uniq
end
def valid_args(function_name, *args)
  if args.any?(&:nil?)
    puts "❌ #{function_name}: One or more required arguments are missing."
    return false
    end

      # Custom validation for the 'attach_pubmed_pdfs' task
  if function_name == 'attach_pubmed_pdfs'
    csv_path = args[0]
    unless File.extname(csv_path) == '.csv'
      puts "❌ #{function_name}: First argument must be a valid CSV file."
      return false
    end
  end

  true
end
# Store file names and CDR data in a CSV
def store_file_names_and_cdr_data(file_names, output_path)
  CSV.open(output_path, 'w') do |csv|
      # Add the header
    csv << ['filename', 'cdr_url', 'has_fileset']
    file_names.each do |file_name|
      cdr_info = get_cdr_duplicate_data(file_name)
      if cdr_info.present?
        cdr_url, has_fileset = cdr_info
        csv << [file_name, cdr_url, has_fileset]
      else
        csv << [file_name, nil, nil]
      end
    end
  end
end

def get_cdr_duplicate_data(identifier)
  puts "[#{Time.now}] Searching for identifier_tesim:\"#{identifier}\""
  result = Hyrax::SolrService.get("identifier_tesim:\"#{identifier}\"",
                          rows: 1,
                          fl: 'id,title_tesim,has_model_ssim,file_set_ids_ssim')['response']['docs']
  if result.empty?
    return nil
  end
  record = result.first
  puts "[#{Time.now}] Found record for #{identifier}: #{record['id']}"
  model_type = record['has_model_ssim'].first.underscore + 's'
  has_fileset = record['file_set_ids_ssim'].present?
  base_url = 'https://cdr.lib.unc.edu/concern/'
  cdr_url = "#{base_url}#{model_type}/#{record['id']}"
  return [cdr_url, has_fileset]
end
