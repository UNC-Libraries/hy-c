desc "Change the admin set of all objects listed to the specified admin set id"
task :change_admin_set, [:id_list_path, :admin_set_id] => :environment do |t, args|
  id_list_path = args[:id_list_path]
  admin_set_id = args[:admin_set_id]

  admin_set = ::AdminSet.where(id: admin_set_id).first
  raise "Not a valid admin set ID: #{admin_set_id}" if admin_set.nil?
  
  puts "Switching works to use admin set #{admin_set.title.first} (#{admin_set.id})"

  lines = File.readlines(id_list_path)
  total = lines.length
  lines.each_with_index do |line, index|
    start = Time.now
    
    id = line.strip
    work = ActiveFedora::Base.find(id)
    
    puts "Changing admin set id for #{work.id} from #{work.admin_set_id} to #{admin_set_id}"
    work.admin_set_id = admin_set_id
    work.save
    
    puts "Updated admin set for #{work.id} (#{index + 1} of #{total}) in #{Time.now - start}s"
  end
end