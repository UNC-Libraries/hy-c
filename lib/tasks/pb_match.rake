# frozen_string_literal: true
DEPOSITOR = ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN']

# WIP: Delete Later
desc 'put pubmed id check'
task :pubmed_id_check, [:identifier] => :environment do |task, args|
  identifier = args[:identifier]
  puts "DOI For #{identifier}: #{pubmed_id_to_doi(identifier)}"
  # if is_valid_pubmed_id?(identifier)
  #   puts "✅ Valid PubMed ID: #{identifier}"
  # else
  #   puts "❌ Invalid PubMed ID: #{identifier}"
  # end
end

desc 'Fetch identifiers from a directory, compare against the CDR, and store the results in a CSV'
task :fetch_identifiers, [:input_dir_path, :output_csv_path] => :environment do |task, args|
  input_dir_path = Rails.root.join(args[:input_dir_path])
  output_csv_path = Rails.root.join(args[:output_csv_path])
  # Array of ['file_name', 'file_extension']
  file_info = file_info_in_dir(input_dir_path)
  # Store ['file_name', 'file_extension' 'cdr_url', 'has_fileset'] names in a CSV
  store_file_info_and_cdr_data(file_info, output_csv_path)
end

desc 'Attach new PDFs to works'
# Arguments:
# 1. fetch_identifiers_output_csv: Path to the CSV file containing the identifiers and CDR data
# 2. full_text_csv: CSV with full-text filenames and extensions
# 3. file_retrieval_directory: Path to the directory where the files are located
# 4. output_dir: Path to the directory where the output files will be saved
task :attach_pubmed_pdfs, [:fetch_identifiers_output_csv, :full_text_csv, :file_retrieval_directory, :output_dir] => :environment do |task, args|
  return unless valid_args('attach_pubmed_pdfs', args[:full_text_csv])
  ingest_service = Tasks::PubmedIngestService.new
  res = {skipped: [], successful: [], failed: [], time: Time.now, depositor: DEPOSITOR, directory_or_csv: args[:full_text_csv], counts: {}}
  file_info = CSV.read(args[:full_text_csv], headers: true)
              .map { |r| [r['file_name'], r['file_extension']] }
              .uniq { |file| file[0] } # Deduplicate filenames

  # Read the CSV file
  fetch_identifiers_output_csv = CSV.read(args[:fetch_identifiers_output_csv], headers: true)
  modified_rows = []
  encountered_alternate_ids = []
  attempted_attachments = 0
  # Iterate through files in the specified directory
  file_info.each_with_index do |file, index|
    file_name, file_extension = file
    # WIP: File Doi to alternate identifiers hash
    alternate_ids_for_file_name = retrieve_alternate_ids(file_name)
    if alternate_ids_for_file_name.nil?
      # Log API failure
      double_log("Failed to retrieve alternate IDs for file from the NCBI API: #{file_name}.#{file_extension}", :warn)
      res[:failed] << {
        'file_name'     => file_name,
        'pdf_attached'  => 'Failed to retrieve alternate IDs from NCBI API',
        'cdr_url'       => nil,
        'has_fileset'   => nil
      }
      next
    end
    # Retrieve the row from the CSV that matches the PMID or PMCID
    row = fetch_identifiers_output_csv.find do |row|
      row['file_name'] == alternate_ids_for_file_name[:pmcid] ||
      row['file_name'] == alternate_ids_for_file_name[:pmid]
    end&.to_h

    # Skip attachment if the row is nil or empty
    if row.nil? || row.empty?
      puts "Row not found for file: #{file_name}.#{file_extension}"
      puts "Alternate IDs: #{alternate_ids_for_file_name.inspect}"
      Rails.logger.warn("Row not found for file: #{file_name}.#{file_extension}")
      next
    end

    # Skip attachment if the doi for the file has already been encountered
    if encountered_alternate_ids.any? { |id_obj| has_matching_ids?(id_obj, alternate_ids_for_file_name) }
      row['pdf_attached'] = 'Skipped: Already encountered this work during current run'
      row['pmid'] = alternate_ids_for_file_name[:pmid]
      row['pmcid'] = alternate_ids_for_file_name[:pmcid]
      row['doi'] = alternate_ids_for_file_name[:doi]
      res[:skipped] << row.to_h
      modified_rows << row
      next
    else
      encountered_alternate_ids << alternate_ids_for_file_name
    end
    # Skip attachment if the work doesn't exist or has a file attached
    if row['cdr_url'].nil? || row['has_fileset'].to_s == 'true'
      skip_message = row['cdr_url'].nil? ? 'No CDR URL' : 'File already attached'
      row['pdf_attached'] = "Skipped: #{skip_message}"
      row['pmid'] = alternate_ids_for_file_name[:pmid]
      row['pmcid'] = alternate_ids_for_file_name[:pmcid]
      row['doi'] = alternate_ids_for_file_name[:doi]
      res[:skipped] << row.to_h
      next
    end
    attempted_attachments += 1
    # Fetch work data using the DOI or file name
    potential_matches = [
     alternate_ids_for_file_name[:doi]   && WorkUtilsHelper.fetch_work_data_by_doi(alternate_ids_for_file_name[:doi]),
     alternate_ids_for_file_name[:pmcid] && WorkUtilsHelper.fetch_work_data_by_alternate_identifier(alternate_ids_for_file_name[:pmcid]),
     alternate_ids_for_file_name[:pmid]  && WorkUtilsHelper.fetch_work_data_by_alternate_identifier(alternate_ids_for_file_name[:pmid])
   ].compact

    hyrax_work = potential_matches.find { |work| work[:work_id].present? }
    puts "Attempting to attach file #{index + 1} of #{file_info.length}:  (#{file_name}.#{file_extension})"
    puts "Inspecting Alternate IDs: #{alternate_ids_for_file_name.inspect}"
    puts "Work Inspection: #{hyrax_work.inspect}"

    # Skip  admin set is not found
    # Add the modified row to the 'modified_rows' array to write to a CSV later
    if hyrax_work.nil? || hyrax_work[:admin_set_id].nil?
      double_log("Admin set or work not found for file: #{file_name}.#{file_extension}", :warn)
      row['pdf_attached'] =  'Failed: Work or Admin Set not found'
      row['pmid'] = alternate_ids_for_file_name[:pmid]
      row['pmcid'] = alternate_ids_for_file_name[:pmcid]
      row['doi'] = alternate_ids_for_file_name[:doi]
      res[:failed] << row.to_h
      modified_rows << row
      next
    end
    # Attach the file to the work
    begin
      file_path = File.join(args[:file_retrieval_directory], "#{file_name}.#{file_extension}")
      ingest_service.attach_pubmed_file(hyrax_work, file_path, DEPOSITOR, Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
      row['pdf_attached'] = 'Success'
      row['pmid'] = alternate_ids_for_file_name[:pmid]
      row['pmcid'] = alternate_ids_for_file_name[:pmcid]
      row['doi'] = alternate_ids_for_file_name[:doi]
      res[:successful] << row.to_h
      modified_rows << row
     rescue StandardError => e
       row['pdf_attached'] = 'Failed: ' + e.message
       row['pmid'] = alternate_ids_for_file_name[:pmid]
       row['pmcid'] = alternate_ids_for_file_name[:pmcid]
       row['doi'] = alternate_ids_for_file_name[:doi]
       res[:failed] << row.to_h.merge('error' => [e.class.to_s, e.message])
       modified_rows << row
       double_log("Error attaching file #{index + 1} of #{file_info.length}:  (#{file_name}.#{file_extension})", :error)
       Rails.logger.error(e.backtrace.join("\n"))
       next
    end
  end
  # Update Counts
  res[:counts][:total_unique_files] = file_info.length
  res[:counts][:failed] = res[:failed].length
  res[:counts][:successful] = res[:successful].length
  res[:counts][:skipped] = res[:skipped].length
  # Write results to JSON
  json_output_path = File.join(args[:output_dir], 'pdf_attachment_results.json')
  File.open(json_output_path, 'w') do |f|
    f.write(JSON.pretty_generate(res))
  end
  # Write modified rows to CSV
  csv_output_path = File.join(args[:output_dir], 'attached_pdfs_output.csv')
  CSV.open(csv_output_path, 'w') do |csv_out|
    csv_out << ['file_name', 'cdr_url', 'has_fileset', 'pdf_attached', 'pmid', 'pmcid', 'doi']
    modified_rows.each do |row|
      csv_out << [row['file_name'], row['cdr_url'], row['has_fileset'], row['pdf_attached'], row['pmid'], row['pmcid'], row['doi']]
    end
  end
  double_log("Results written to #{json_output_path} and #{csv_output_path}", :info)
  double_log("Attempted Attachments: #{attempted_attachments}, Successful: #{res[:successful].length}, Failed: #{res[:failed].length}, Skipped: #{res[:skipped].length}", :info)
end

def has_matching_ids?(existing_ids, current_ids)
  # Check if the identifier matches any of the alternate IDs
  existing_ids[:pmid] == current_ids[:pmid] ||
  existing_ids[:pmcid] == current_ids[:pmcid] ||
  existing_ids[:doi] == current_ids[:doi]
end

def retrieve_alternate_ids(identifier)
  # Send a request to the PubMed conversion API
  response = HTTParty.get("https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?ids=#{identifier}")
  doc = Nokogiri::XML(response.body)
  record = doc.at_xpath('//record')
  if record && record['status'] != 'error'
    res = {
      pmid:  record['pmid'],
      pmcid: record['pmcid'],
      doi: record['doi'],
    }
    return res
  else
    return nil
  end
end

def double_log(message, level)
  puts message
  case level
  when :info
    Rails.logger.info(message)
  when :warn
    Rails.logger.warn(message)
  when :error
    Rails.logger.error(message)
  else
    Rails.logger.debug(message)
  end
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
    csv << ['file_name', 'file_extension', 'cdr_url', 'has_fileset']
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
