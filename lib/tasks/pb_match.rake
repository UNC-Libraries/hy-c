# frozen_string_literal: true
# Notes:
# 1. Script uses PMC-OAI API to retrieve metadata and make comparisons of alternate IDs. (PMCID, PMID)
# 2. PMC requests scripts making >100 requests be ran outside of peak hours. (5 AM - 9 PM)
DEPOSITOR = ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
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
# 2. file_retrieval_directory: Path to the directory where the files are located
# 3. output_dir: Path to the directory where the output files will be saved
# 4. admin_set_title: The admin set into which new works should be ingested
task :attach_pubmed_pdfs, [:fetch_identifiers_output_csv, :file_retrieval_directory, :output_dir, :admin_set_title] => :environment do |task, args|
  return unless valid_args('attach_pubmed_pdfs', args[:fetch_identifiers_output_csv], args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title])
  res = {
  skipped: [], successfully_attached: [], successfully_ingested: [], failed: [],
  time: Time.now, depositor: DEPOSITOR, file_retrieval_directory: args[:file_retrieval_directory],
  output_dir: args[:output_dir], admin_set: args[:admin_set_title], counts: {}
}
  ingest_service = Tasks::PubmedIngest::PubmedIngestService.new({
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => DEPOSITOR,
    'attachment_results' => res,
    'file_retrieval_directory' => args[:file_retrieval_directory]
  })

  file_info = file_info_in_dir(args[:file_retrieval_directory])
  identifiers_csv = CSV.read(args[:fetch_identifiers_output_csv], headers: true)

  modified_rows = []
  encountered_alternate_ids = []
  attempted_attachments = 0

  file_info.each_with_index do |file, index|
    file_name, file_extension = file
    alternate_ids = retrieve_alternate_ids(file_name)

    if alternate_ids.nil?
      double_log("Failed to retrieve alternate IDs for file: #{file_name}.#{file_extension}", :warn)
      res[:failed] << {
        file_name: "#{file_name}.#{file_extension}",
        pdf_attached: 'Failed to retrieve alternate IDs from NCBI API',
        cdr_url: nil,
        has_fileset: nil
      }
      next
    end

    row = identifiers_csv.find do |r|
      r['file_name'] == alternate_ids[:pmcid] || r['file_name'] == alternate_ids[:pmid]
    end&.to_h || {}

    row['pmid'] = alternate_ids[:pmid]
    row['pmcid'] = alternate_ids[:pmcid]
    row['doi']  = alternate_ids[:doi]
    row['file_name'] = "#{file_name}.#{file_extension}"

    if row.empty?
      double_log("Row not found for file: #{file_name}.#{file_extension}. Alternate IDs: #{alternate_ids.inspect}", :warn)
      next
    end

    if encountered_alternate_ids.any? { |ids| has_matching_ids?(ids, alternate_ids) }
      row['pdf_attached'] = 'Skipped: Already encountered this work during current run'
      res[:skipped] << row
      modified_rows << row
      next
    else
      encountered_alternate_ids << alternate_ids
    end

    if row['cdr_url'].nil?
      row['pdf_attached'] = 'Skipped: No CDR URL'
      row['path'] = "#{args[:file_retrieval_directory]}/#{file_name}.#{file_extension}"
      res[:skipped] << row
      modified_rows << row
      next
    end

    if row['has_fileset'].to_s == 'true'
      row['pdf_attached'] = 'Skipped: File already attached'
      res[:skipped] << row
      modified_rows << row
      next
    end

    attempted_attachments += 1

    potential_matches = [
      alternate_ids[:doi]   && WorkUtilsHelper.fetch_work_data_by_doi(alternate_ids[:doi]),
      alternate_ids[:pmcid] && WorkUtilsHelper.fetch_work_data_by_alternate_identifier(alternate_ids[:pmcid]),
      alternate_ids[:pmid]  && WorkUtilsHelper.fetch_work_data_by_alternate_identifier(alternate_ids[:pmid])
    ].compact

    hyrax_work = potential_matches.find { |w| w[:work_id].present? }

    puts "Attempting to attach file #{index + 1} of #{file_info.length}:  (#{file_name}.#{file_extension})"
    puts "Inspecting Alternate IDs: #{alternate_ids.inspect}"
    puts "Work Inspection: #{hyrax_work.inspect}"

    if hyrax_work.nil? || hyrax_work[:admin_set_id].nil?
      double_log("Admin set or work not found for file: #{file_name}.#{file_extension}", :warn)
      row['pdf_attached'] = 'Failed: Work or Admin Set not found'
      res[:failed] << row
      modified_rows << row
      next
    end

    begin
      file_path = Pathname.new(args[:file_retrieval_directory]).absolute? ?
              File.join(args[:file_retrieval_directory], "#{file_name}.#{file_extension}") :
              Rails.root.join(args[:file_retrieval_directory], "#{file_name}.#{file_extension}")
      ingest_service.attach_pubmed_file(hyrax_work, file_path, DEPOSITOR, Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
      row['pdf_attached'] = 'Success'
      res[:successfully_attached] << row
      modified_rows << row
    rescue StandardError => e
      row['pdf_attached'] = 'Failed: ' + e.message
      res[:failed] << row.merge('error' => [e.class.to_s, e.message])
      modified_rows << row
      double_log("Error attaching file #{index + 1} of #{file_info.length}:  (#{file_name}.#{file_extension})", :error)
      Rails.logger.error(e.backtrace.join("\n"))
      next
    end
  end
  ingest_service = Tasks::PubmedIngest::PubmedIngestService.new({
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => DEPOSITOR,
    'attachment_results' => res,
    'file_retrieval_directory' => args[:file_retrieval_directory]
  })
  res = ingest_service.ingest_publications

  res[:counts][:total_unique_files] = file_info.length
  res[:counts][:failed] = res[:failed].length
  res[:counts][:successfully_attached] = res[:successfully_attached].length
  res[:counts][:successfully_ingested] = res[:successfully_ingested].length
  res[:counts][:skipped] = res[:skipped].length

  json_output_path = Rails.root.join(args[:output_dir], "pdf_attachment_results_#{res[:time].strftime('%Y%m%d%H%M%S')}.json")
  File.open(json_output_path, 'w') { |f| f.write(JSON.pretty_generate(res)) }

  double_log("Results written to #{json_output_path}", :info)
  double_log("Attempted: #{attempted_attachments}, Ingested: #{res[:successfully_ingested].length}, Attached: #{res[:successfully_attached].length}, Failed: #{res[:failed].length}, Skipped: #{res[:skipped].length}", :info)
  double_log('Sending email with results', :info)
  begin
    report = Tasks::PubmedIngest::PubmedReportingService.generate_report(res)
    PubmedReportMailer.pubmed_report_email(report).deliver_now
    double_log('Email sent successfully', :info)
  rescue StandardError => e
    double_log("Failed to send email: #{e.message}", :error)
    double_log(e.backtrace.join("\n"))
  end
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
  abs_dir = Pathname.new(directory).absolute? ? directory : Rails.root.join(directory)
  Dir.entries(abs_dir)
     .select { |f| !File.directory?(File.join(abs_dir, f)) }
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
