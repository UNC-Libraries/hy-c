desc "Finds records with multiple affiliations"
task :find_multiple_affiliations, [:id_list_path] => :environment do |t, args|
  people = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
            'reviewers', 'translators']

  id_list_path = args[:id_list_path]

  start_total = Time.now
  records_to_update = []

  lines = File.readlines(id_list_path)
  total = lines.length
  lines.each_with_index do |line, index|
    id = line.strip

    puts "Updating work #{id}, #{index + 1} of #{total}"

    begin
      work = ActiveFedora::Base.find(id)
    rescue
      next
    end
    people.each do |person|
      if work.attributes.keys.member?(person)
        if !work[person].blank?
          work[person].each do |p|
            affil_vals = JSON.parse(p.affiliation.to_json)
            if affil_vals.length > 1
              puts "#{id} needs to be updated"
              records_to_update.push({ id: id, name: p.name.first, affils: affil_vals })
            end
          end
        end
      end
    end
  end

  CSV.open('/tmp/records-for-updating.csv', "wb") do |csv|
    csv << ['id', 'name', 'affiliations']
    records_to_update.each do |record|
      csv << [record[:id], record[:name], record[:affils].join('||')]
    end
  end
  puts "Finished checking all works in #{Time.now - start_total}s."
end