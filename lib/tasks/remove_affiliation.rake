desc "Remove all affiliations but the most specific if present for all people objects on the items listed"
task :remove_affiliation, [:record_list_path] => :environment do |t, args|
  people = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
            'reviewers', 'translators']

  record_list_path = args[:record_list_path]
  start_total = Time.now

  # Iterate through each object to update affiliations
  files = Hyc::AffiliationsToUpdate.generate_records_to_update(record_list_path)
  records = JSON.parse(files)
  total = records.length

  records.each_with_index do |record, index|
    # puts "Updating affiliations for work #{record['id']}, #{index + 1} of #{total}"

    work = ActiveFedora::Base.find(record['id'])
    people.each do |person|
      start = Time.now

      if work.attributes.keys.member?(person) && record.has_key?(person)
        unless work[person].blank?
          updated = false
          updates = record[person]

          work[person].each do |p|
            affil_vals = JSON.parse(p.affiliation.to_json)
            name = JSON.parse(p.name.to_json)[0]

            # Delete any but the most specific affiliation
            affil_vals.each do |affil_val|
              updates.each do |u|
                if name == u[:name] && affil_val != u[:affiliation]
                  puts "Deleting affiliation: #{affil_val} for record #{work.id} and person: #{name}"
                  p.affiliation.delete(affil_val)
                  updated = true
                else
                 # puts "Affiliation: #{affil_val} OK for record #{work.id} and person: #{name}"
                end
              end
            end
          end

          if updated
            work.save!
           # puts "++ Updated affiliation for #{person} on #{work.id} in #{Time.now - start}s"
          end
        end
      end
    end
  end
  puts "Finished updating all works in #{Time.now - start_total}s."
end