# frozen_string_literal: true
# Hardcode absolute paths for input and output directories
INPUT_PATH = '/home/dcam/pmc_pdfs/sample'
OUTPUT_PATH = '/home/dcam/pb_match_results.csv'

desc 'Fetch identifiers from a directory, compare against the CDR, and store the results in a CSV'
task fetch_identifiers: :environment do |task, args|
  path = Rails.root.join(INPUT_PATH)
  output_path = Rails.root.join(OUTPUT_PATH)
    # Fetch file names from the directory
    # Strip the file extension and remove duplicates
  file_names = Dir.entries(path).select { |f| !File.directory? f }.map { |f| File.basename(f, '.*') }.uniq
    # Store the file names in a CSV
  store_file_names_and_cdr_data(file_names, output_path)
end

desc 'Attach new PDFs to works'
task :attach_pubmed_pdfs, [:input_csv_path, :pdf_path] => :environment do |task, args|
  return unless valid_args('attach_pubmed_pdfs', args[:input_csv_path], args[:pdf_path])
  input_csv_arr = []
  CSV.foreach(args[:input_csv_path], headers: true) do |row|
    input_csv_arr << {
        'filename' => row['filename'],
        'cdr_url' => row['cdr_url'],
        'has_fileset' => row['has_fileset']
    }
  end
    # Inspect the first 5 rows, print the size of the array
    # puts "Total rows: #{input_csv_arr.size}"
    # for hash in input_csv_arr[0..4]
    #     puts hash.inspect
    # end
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
