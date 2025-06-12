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

desc 'Ingest new PubMed PDFs and attach them to Hyrax works if matched'
task :pubmed_ingest, [:file_retrieval_directory, :output_dir, :admin_set_title] => :environment do |task, args|
  return unless valid_args('pubmed_ingest', args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title])
  file_retrieval_directory = Pathname.new(args[:file_retrieval_directory]).absolute? ?
                             args[:file_retrieval_directory] :
                             Rails.root.join(args[:file_retrieval_directory])
  coordinator = Tasks::PubmedIngest::PubmedIngestCoordinatorService.new({
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => DEPOSITOR,
    'file_retrieval_directory' => file_retrieval_directory,
    'output_dir' => args[:output_dir]
  })
  res = coordinator.run
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
