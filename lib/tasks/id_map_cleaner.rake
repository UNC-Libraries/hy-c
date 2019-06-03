desc "Creates mapping file without duplicate ids"
task :id_map_cleaner, [:old_mapping_file, :new_mapping_file, :duplicate_log] => :environment do |t, args|
  old_mapping_file = args[:old_mapping_file]
  new_mapping_file = args[:new_mapping_file]
  duplicate_log = args[:duplicate_log]

  mappings = {}

  # load original mappings into hash, logging and overwriting duplicates
  File.open(old_mapping_file) do |file|
    file.each do |line|
      key,value = line.strip.split(',')
      if mappings[key]
        # map work instead of file_sets for simple objects
        if (mappings[key].split('/')[1] == value.split('/')[1]) && (value.split('/')[0] == 'parent')
          next
        end
        File.open(duplicate_log, 'a+') do |dup|
          dup.puts "#{key},#{mappings[key]}"
        end
      end
      mappings[key] = value
    end
  end

  # write deduped mappings to file
  File.open(new_mapping_file, 'w+') do |file|
    mappings.each do |k,v|
      file.puts "#{k},#{v}"
    end
  end
end
