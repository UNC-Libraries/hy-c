class MigrationHelper
  def self.get_uuid_from_path(path)
    path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
  end

  def self.create_filepath_hash(filename, hash)
    File.open(filename) do |file|
      file.each do |line|
        value = line.strip
        key = get_uuid_from_path(value)
        if !key.blank?
          hash[key] = value
        end
      end
    end
  end

  def self.get_collection_uuids(collection_ids_file)
    collection_uuids = Array.new
    File.open(collection_ids_file) do |file|
      file.each do |line|
        if !line.blank? && !get_uuid_from_path(line.strip).blank?
          collection_uuids.append(get_uuid_from_path(line.strip))
        end
      end
    end

    collection_uuids
  end
  
  def self.retry_operation(message = nil)
    begin
      retries ||= 0
      yield
    rescue Exception => e
      puts "[#{Time.now.to_s}] #{e}"
      puts e.backtrace.map{ |x| x.match(/^\/net\/deploy\/ir\/test\/releases.*/)}.compact
      puts message unless message.nil?
      sleep(10)
      retry if (retries += 1) < 5
      # log full backtrace if not recovered
      puts e.backtrace
      # send abort message and backtrace to terminal
      abort("[#{Time.now}] could not recover; aborting migration\nbacktrace:\n#{e.backtrace}")
    end
  end
end