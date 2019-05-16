desc "Attach children to parent records as members. Input is a CSV file with the parent id as the first column, and a pipe delimited set of child ids as the second column."
task :attach_child_to_parent, [:mapping_path] => :environment do |t, args|
  map_path = args[:mapping_path]
  
  start_total = Time.now
  
  puts "Attaching children to parent records"

  lines = File.readlines(map_path)
  total = lines.length
  lines.each_with_index do |line, index|
    start = Time.now
    
    parent_id, child_ids = line.split(',').collect(&:strip)
    child_ids = child_ids.split('|')
    
    parent = ActiveFedora::Base.find(parent_id)
    raise "Parent #{parent_id} does not exist" if parent.nil?
    
    child_ids.each do |child_id|
      child = ActiveFedora::Base.find(child_id)
      raise "Child #{child_id} does not exist" if child.nil?
      
      parent.ordered_members << child
      parent.members << child
      
      puts "++ Added #{child_id} to #{parent_id}"
    end

    parent.save
    
    puts "Added #{child_ids.length} children to #{parent_id} (#{index + 1} of #{total}) in #{Time.now - start}s"
  end
  
  puts "Finished updating all works in #{Time.now - start_total}s."
end