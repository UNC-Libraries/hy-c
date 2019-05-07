desc "Adds hog data files to ordered_members array"
task :hog_data_files => :environment do
  # get list of missing files
  missing_files = 'lib/tasks/missing_hog_data_files.txt'
  if !File.exist?(missing_files)
    all_files = []
    attached_files = []

    File.readlines('lib/tasks/hog_data_files.txt').each do |line|
      all_files << line.strip
    end

    puts all_files.length

    File.readlines('lib/tasks/hog_data_attached.txt').each do |line|
      attached_files << line.strip
    end

    puts attached_files.length

    missing_file_ids = all_files - attached_files

    puts missing_file_ids.length

    missing_file_ids.each do |id|
      File.open(missing_files, 'a+') do |file|
        file.puts(id)
      end
    end
  end

  # find hog data work
  d = Dissertation.find('rx913r86b')
  # list current file/child count
  puts d.ordered_members.to_a.length
  # add missing files to set
  File.readlines('lib/tasks/missing_hog_data_files.txt').each_with_index do |line, index|
    puts "#{index+1}, #{line}"
    f = FileSet.find(line.strip)
    d.ordered_members << f
    if index % 25 == 0
      d.save!
    end
  end
  d.save!
  # verify that number of files/children has changed
  puts d.ordered_members.to_a.length
end