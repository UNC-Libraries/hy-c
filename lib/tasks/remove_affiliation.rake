desc "Remove all affiliations but the most specific if present for all people objects on the items listed"
task :remove_affiliation, [:id_list_path] => :environment do |t, args|
  people = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
            'reviewers', 'translators']

  id_list_path = args[:id_list_path]
  start_total = Time.now

  # Iterate through each object to update affiliations
  lines = File.readlines(id_list_path)
  total = lines.length
  lines.each_with_index do |line, index|
    id = line.strip

    puts "Updating work #{id}, #{index + 1} of #{total}"

    work = ActiveFedora::Base.find(id)
    people.each do |person|
      start = Time.now
      if work.attributes.keys.member?(person)
        unless work[person].blank?
          updated = false

          work[person].each do |p|
            affil_vals = JSON.parse(p.affiliation.to_json)

            if affil_vals.length == 1 # Already has most specific affiliation
              next
            end

            # Delete any but the most specific affiliation
            affil_vals.each do |affil_val|
              expanded_replacement = DepartmentsService.label(affil_val)&.split(';')
              if expanded_replacement.nil? || affil_val != expanded_replacement.last
                puts "Deleting affiliation: #{affil_val} for record #{work.id}"
                p.affiliation.delete(affil_val)
              end
            end

            updated = true
          end

          if updated
            puts "++ Updated affiliation for #{person} on #{work.id} in #{Time.now - start}s"
          end
        end
      end
    end
  end
  puts "Finished updating all works in #{Time.now - start_total}s."
end
