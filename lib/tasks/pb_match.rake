# frozen_string_literal: true
# Hardcode absolute paths for input and output directories
INPUT_PATH = '/home/dcam/pmc_pdfs/sample'
OUTPUT_PATH = '/home/dcam/pb_match_results.csv'
DEPOSITOR = ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN']

desc 'Fetch identifiers from a directory, compare against the CDR, and store the results in a CSV'
task fetch_identifiers: :environment do |task, args|
  path = Rails.root.join(INPUT_PATH)
  output_path = Rails.root.join(OUTPUT_PATH)
  # Array of ['file_name', 'file_extension']
  file_info = file_info_in_dir(path)
  # Store ['file_name', 'file_extension' 'cdr_url', 'has_fileset'] names in a CSV
  store_file_info_and_cdr_data(file_info, output_path)
end

desc 'Attach new PDFs to works'
# Arguments:
# 1. fetch_identifiers_output_csv: Path to the CSV file containing the identifiers and CDR data
# 2. full_text_dir_or_csv: Path to the directory or CSV file containing the full text files
# 3. file_retrieval_directory: Path to the directory where the files are located. Should be the same as full_text_dir_or_csv if it's a directory
# 4. output_dir: Path to the directory where the output files will be saved
task :attach_pubmed_pdfs, [:fetch_identifiers_output_csv, :full_text_dir_or_csv, :file_retrieval_directory, :output_dir] => :environment do |task, args|
  return unless valid_args('attach_pubmed_pdfs', args[:full_text_dir_or_csv])
  ingest_service = Tasks::PubmedIngestService.new
  res = {skipped: [], successful: [], failed: [], time: Time.now, depositor: DEPOSITOR, directory_or_csv: args[:full_text_dir_or_csv]}

#   Retrieve all files within pdf directory
  file_info =
  if File.extname(args[:full_text_dir_or_csv]) == '.csv'
    CSV.read(args[:full_text_dir_or_csv], headers: true).map { |r| [r['file_name'], r['file_extension']] }
  else
    file_info_in_dir(args[:full_text_dir_or_csv])
  end
  # Read the CSV file
  fetch_identifiers_output_csv = CSV.read(args[:fetch_identifiers_output_csv], headers: true)
  modified_rows = []
  attempted_attachements = 0
  # Iterate through files in the specified directory
  file_info.each_with_index do |file, index|
    file_name = file[0]
    file_extension = file[1]
    # Retrieve the row from the CSV that matches the file name
    row = fetch_identifiers_output_csv.find { |row| row['file_name'] == file_name }.to_h
    if row.nil?
      next
    end
    # Set 'pdf_attached' to 'Skipped' if the below conditions are met and categorize the row as skipped
    if row['cdr_url'].nil? || row['has_fileset'].to_s == 'true'
      skip_message = row['cdr_url'].nil? ? 'No CDR URL' : 'File already attached'
      row['pdf_attached'] = "Skipped: #{skip_message}"
      res[:skipped] << row
      next
    end
    # Only print rows that are not skipped
    attempted_attachements += 1
    puts "Attempting to attach file #{index} of #{file_info.length}:  (#{file_name}.#{file_extension})"
    hyrax_work = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(row['file_name'])
    # Skip the row if the work or admin set is not found
    # Modify the 'pdf_attached' field depending on the result of the attachment, and categorize the row as successful or failed
    # Add the modified row to the 'modified_rows' array to write to a CSV later
    if hyrax_work[:work_id].nil? || hyrax_work[:admin_set_id].nil?
      concern = hyrax_work[:work_id].nil? ? 'Work' : 'Admin Set'
      row['pdf_attached'] =  "Failed: #{concern} not found"
      res[:failed] << row
      modified_rows << row
      next
    end
    begin
      file_path = File.join(args[:file_retrieval_directory], "#{file_name}.#{file_extension}")
      ingest_service.attach_pubmed_file(hyrax_work, file_path, DEPOSITOR, Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
      row['pdf_attached'] = 'Success'
      res[:successful] << row
      modified_rows << row
     rescue StandardError => e
       res[:failed] << row.merge('error' => [e.class.to_s, e.message])
       modified_rows << row
       puts "Error attaching file #{index} of #{file_info.length}:  (#{file_name}.#{file_extension})"
       Rails.logger.error("Error attaching file #{index} of #{file_info.length}:  (#{file_name}.#{file_extension})")
       Rails.logger.error(e.backtrace.join("\n"))
       next
    end
  end
  # Write results to JSON
  json_output_path = File.join(args[:output_dir], 'pdf_attachment_results.json')
  File.open(json_output_path, 'w') do |f|
    f.write(JSON.pretty_generate(res))
  end
  # Write modified rows to CSV
  csv_output_path = File.join(args[:output_dir], 'attached_pdfs_output.csv')
  CSV.open(csv_output_path, 'w') do |csv_out|
    csv_out << ['file_name', 'cdr_url', 'has_fileset', 'pdf_attached']
    modified_rows.each do |row|
      csv_out << [row['file_name'], row['cdr_url'], row['has_fileset'], row['pdf_attached']]
    end
  end
  double_log("Results written to #{json_output_path} and #{csv_output_path}")
  double_log("Attemped Attachments: #{attempted_attachements}, Successful: #{res[:successful].length}, Failed: #{res[:failed].length}, Skipped: #{res[:skipped].length}")
end

def double_log(message)
  puts message
  Rails.logger.info(message)
end

def file_info_in_dir(directory)
  Dir.entries(directory)
     .select { |f| !File.directory?(File.join(directory, f)) }
     .map { |f| [File.basename(f, '.*'), File.extname(f).delete('.')] }
     .uniq
end
def valid_args(function_name, *args)
  if args.any?(&:nil?)
    puts "❌ #{function_name}: One or more required arguments are missing."
    return false
    end

  true
end
# Store file names and CDR data in a CSV
def store_file_info_and_cdr_data(file_info, output_path)
  CSV.open(output_path, 'w') do |csv|
      # Add the header
    csv << ['file_name', 'file_extension' 'cdr_url', 'has_fileset']
    file_info.each do |file|
      file_name = file[0]
      file_extension = file[1]
      cdr_info = get_cdr_duplicate_data(file_name)
      if cdr_info.present?
        cdr_url, has_fileset = cdr_info
        csv << [file_name, file_extension, cdr_url, has_fileset]
      else
        csv << [file_name, file_extension, nil, nil]
      end
    end
  end
end

def get_cdr_duplicate_data(identifier)
  result = Hyrax::SolrService.get("identifier_tesim:\"#{identifier}\"",
                          rows: 1,
                          fl: 'id,title_tesim,has_model_ssim,file_set_ids_ssim')['response']['docs']
  if result.empty?
    return nil
  end
  record = result.first
  model_type = record['has_model_ssim'].first.underscore + 's'
  has_fileset = record['file_set_ids_ssim'].present?
  base_url = 'https://cdr.lib.unc.edu/concern/'
  cdr_url = "#{base_url}#{model_type}/#{record['id']}"
  return [cdr_url, has_fileset]
end
