desc "Removes 'College of Arts and Sciences' from affiliation list for people and works associated with Department \
of Allied Health Sciences"
task :remediate_person_affiliations => :environment do
  people = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
              'reviewers', 'translators']

  # Use solr query to get ids of records to fix
  record_list = 'lib/tasks/test_affiliations.csv'
  
  ALLIED_AFFILS = ['Curriculum in Human Movement Science',
                   'Division of Clinical Laboratory Science',
                   'Division of Clinical Rehabilitation and Mental Health Counseling',
                   'Division of Occupational Science',
                   'Division of Occupational Science and Occupational Therapy',
                   'Division of Physical Therapy', 
                   'Division of Radiologic Science',
                   'Division of Speech and Hearing Sciences',
                   'Physician Assistant Program',
                   'Department of Allied Health Sciences']

  # update works with allied health affiliation
  File.readlines(record_list).each_with_index do |line, index|
    model, id = line.split(',').collect(&:strip)
    work = ActiveFedora::Base.find(id)
    people.each do |person|
      if  work.attributes.keys.member?(person)
        if !work[person].blank?
          # Only update records if there are changes
          values = Array.new
          updated = false
          
          work[person].each do |p|
            affil_vals = JSON.parse(p.affiliation.to_json)
            if (affil_vals & ALLIED_AFFILS).length > 0
              result = p.affiliation.delete?('College of Arts and Sciences')
              # Use this for testing if need to add in a second affiliation
              # puts "ADDING"
              # p.affiliation << 'College of Arts and Sciences'
              # result = true
            else
              result = nil
            end
            
            p_hash = JSON.parse(p.to_json)
            if !result.nil?
              updated = true
              p_hash.delete('id')
            end
            values << p_hash
          end
          
          if updated
            puts "Replacing #{person} values for #{work.id}"
            
            work[person] = nil
            work.save!

            work.update(("#{person.to_s}_attributes") => values)
          end
        end
      end
    end
  end
end
