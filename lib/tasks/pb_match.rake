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
# Requiring a directory to be specified to avoid searching for the PDF
task :attach_pubmed_pdfs, [:input_csv_path, :input_pdf_dir_or_csv] => :environment do |task, args|
  return unless valid_args('attach_pubmed_pdfs', args[:input_csv_path], args[:input_pdf_dir_or_csv])
#   WIP: Implement the PubmedIngestService
  ingest_service = Tasks::PubmedIngestService.new
  res = {skipped: [], successful: [], failed: [], time: Time.now, depositor: ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN'], directory_or_csv: args[:input_pdf_dir_or_csv]}

#   Retrieve all files within pdf directory
  file_names =
  if File.extname(args[:input_pdf_dir_or_csv]) == '.csv'
    CSV.read(args[:input_pdf_dir_or_csv], headers: true).map { |r| r['filename'] }
  else
    filenames_in_dir(args[:input_pdf_dir_or_csv])
  end
  # Read the CSV file
  csv = CSV.read(args[:input_csv_path], headers: true)
  # WIP: Likely remove later
  puts "Found #{file_names.length} files in the directory"
  modified_rows = []
  attempted_attachements = 0
  # WIP: Remove with index
  # Iterate through files in the specified directory
  file_names.each_with_index do |file_name, index|
    # WIP: Short loop for testing
    break if attempted_attachements > 2
    # Retrieve the row from the CSV that matches the file name
    row = csv.find { |row| row['filename'] == file_name }.to_h
    if row.nil?
      # puts "No CSV entry found for #{file_name}"
      next
    end
    # WIP: Likely remove later, Log for debugging
    # puts "Processing #{file_name}, Index: #{index}"
    # puts "Row: #{row}"
    # Set 'pdf_attached' to 'Skipped' if the below conditions are met and categorize the row as skipped
    if row['cdr_url'].nil? || row['has_fileset'].to_s != 'true'
      skip_message = row['cdr_url'].nil? ? 'No CDR URL' : 'File already attached'
      row['pdf_attached'] = "Skipped: #{skip_message}"
      res[:skipped] << row
      # WIP: Likely remove later, Log for debugging
      # puts "Skipped: #{skip_message}"
      next
    end
    # WIP: Likely remove later
    puts "Fetching work data for #{row['filename']}"
    # Only print rows that are not skipped
    attempted_attachements += 1
    puts "Processing #{file_name}, Index: #{index}"
    puts "Row: #{row}"
    hyrax_work = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(row['filename'])
    # Skip the row if the work or admin set is not found
    if hyrax_work[:work_id].nil? || hyrax_work[:admin_set_id].nil?
      concern = hyrax_work[:work_id].nil? ? 'Work' : 'Admin Set'
      row['pdf_attached'] =  "Failed: #{concern} not found"
      res[:failed] << row
      # WIP: Likely remove later, Log for debugging
      puts "Failed: #{concern} not found"
      next
    end
    # WIP: Likely remove later
    puts "Successfully fetched work with ID: #{hyrax_work[:work_id]}. Admin set ID: #{hyrax_work[:admin_set_id]}. Creating work object."
     # WIP: Implement the PubmedIngestService
    attachment_result = ingest_service.attach_pubmed_pdf(row, args[:input_pdf_dir_or_csv])
    # Modify the 'pdf_attached' field depending on the result of the attachment
    # Categorize the modified row depending on the result of the attachment
    # add id, title to the row
    modified_rows << attachment_result
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
