desc "Updates the permissions of children (files and works) to be at least as restrictive as their parent work"
task :inherit_parent_access, [:id_list_path] => :environment do |t, args|
  vis_private = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
  
  id_list_path = args[:id_list_path]
  
  start_total = Time.now
  
  lines = File.readlines(id_list_path)
  total = lines.length
  puts "Updating the access restrictions of the children of #{total} works to match their parents"
  
  lines.each_with_index do |line, index|
    start = Time.now
    
    id = line.strip
    parent = ActiveFedora::Base.find(id)
    
    puts "Updating parent work #{parent.id}: #{parent.visibility} #{parent.embargo_release_date} #{parent.visibility_during_embargo} #{parent.visibility_after_embargo}"
    
    update_children(parent)
    
    puts "Finished with children of #{parent.id} (#{index + 1} of #{total}) in #{Time.now - start}s"
  end
  
  puts "Finished updating all works in #{Time.now - start_total}s."
end

def update_children(parent)
  vis_private = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
  
  parent_vis = parent.visibility
  parent_embargo_release_date = parent.embargo_release_date

  members = parent.member_ids.map { |member_id| parent = ActiveFedora::Base.find(member_id) }

  members.each do |child|
    child_time = Time.now
    
    update = false
    
    child_vis = child.visibility
    child_embargo_release_date = child.embargo_release_date
    
    if more_restrictive?(parent_vis, child_vis)
      child.visibility = parent_vis
      updated = true
      puts "++ Changing child vis from #{child_vis} to #{parent_vis}"
    end
    
    # If the parent has an embargo and the child doesn't, add embargo to child
    if !parent_embargo_release_date.nil? && child_embargo_release_date.nil?
      # Do not add embargo to child if it is marked private
      if child_vis != vis_private
        child.embargo_release_date = parent_embargo_release_date
        child.visibility_during_embargo = parent.visibility_during_embargo
        child.visibility_after_embargo = parent.visibility_after_embargo
        puts "++ Adding embargo to child #{parent_embargo_release_date}"
        updated = true
      end
    end
  
    if updated
      child.save!
      puts "+ Updated child #{child.id} of #{parent.id} in #{Time.now - child_time}s"
    end
    
    # If the child is a work, then update all of its children as well
    if !child.is_a?(FileSet)
      update_children(child)
    end
  end
end

def more_restrictive?(dest_vis, current_vis)
  vis_private = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
  vis_public = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  vis_authenticated = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
  
  case(dest_vis)
  when vis_private
    if current_vis == vis_authenticated || current_vis == vis_public
      return true
    end
  when vis_authenticated
    if current_vis == vis_public
      return true
    end
  end
  
  false
end