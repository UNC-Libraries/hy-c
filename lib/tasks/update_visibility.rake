desc "Updates the permissions of the listed works to the provided visibility. Requires a path to a list of identifiers to update, and the visibility level to set them all to."
task :update_visibility, [:id_list_path, :visibility_arg] => :environment do |t, args|
  vis_private = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
  vis_public = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  vis_authenticated = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
  
  id_list_path = args[:id_list_path]
  
  case(args[:visibility_arg])
  when 'public'
    new_visibility = vis_public
  when 'private'
    new_visibility = vis_private
  when 'authenticated'
    new_visibility = vis_authenticated
  else
    raise "Unable to assign unsupported access restriction '#{args[:visibility_arg]}'"
  end
  
  start_total = Time.now
  
  lines = File.readlines(id_list_path)
  total = lines.length
  puts "Updating access restrictions for #{total} works to #{new_visibility}"
  
  lines.each_with_index do |line, index|
    start = Time.now
    
    id = line.strip
    work = ActiveFedora::Base.find(id)
    
    work.visibility = new_visibility
    work.save
    
    puts "Updated access visibility for #{work.id} (#{index + 1} of #{total}) in #{Time.now - start}s"
  end
  
  puts "Finished updating all works in #{Time.now - start_total}s."
end