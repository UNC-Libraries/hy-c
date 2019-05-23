desc "Replaces an affiliation value with a new value if present for all people objects on the items listed"
task :replace_affiliation, [:id_list_path, :replace_affil, :replace_with] => :environment do |t, args|
  people = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
              'reviewers', 'translators']

  id_list_path = args[:id_list_path]
  replace_affil = args[:replace_affil]
  replace_with = args[:replace_with]
  
  start_total = Time.now
  
  expanded_replacement = DepartmentsService.label(replace_with)&.split('; ')
  raise "#{replace_with} is not in the department vocabulary" if expanded_replacement.nil?

  # Iterate through each object to replace affiliations
  puts "Replacing affiliation #{replace_affil} with #{replace_with}"

  lines = File.readlines(id_list_path)
  total = lines.length
  lines.each_with_index do |line, index|
    id = line.strip
    
    puts "Updating work #{id}, #{index + 1} of #{total}"
    
    work = ActiveFedora::Base.find(id)
    people.each do |person|
      start = Time.now
      if work.attributes.keys.member?(person)
        if !work[person].blank?
          # Only update records if there are changes
          values = Array.new
          updated = false
          
          work[person].each do |p|
            replaced = false
            
            affil_vals = JSON.parse(p.affiliation.to_json)
            if affil_vals.include?(replace_affil)
              # Clear out all existing affiliations for this person, since parent affiliations may exist
              affil_vals.each do |affil_val|
                p.affiliation.delete(affil_val)
              end
              
              p.affiliation << expanded_replacement
              replaced = true
            end
            
            p_hash = JSON.parse(p.to_json)
            if replaced
              updated = true
              p_hash.delete('id')
            end
            values << p_hash
          end
          
          if updated
            work[person] = nil
            work.save!

            work.update(("#{person.to_s}_attributes") => values)
            puts "++ Replaced affiliation for #{person} on #{work.id} in #{Time.now - start}s"
          end
        end
      end
    end
  end
  puts "Finished updating all works in #{Time.now - start_total}s."
end
