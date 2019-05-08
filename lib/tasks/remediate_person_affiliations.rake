desc "Removes 'College of Arts and Sciences' from affiliation list for people and works associated with Department \
of Allied Health Sciences"
task :remediate_person_affiliations => :environment do
  people = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
            'reviewers', 'translators']

  # Use solr query to get ids of records to fix
  record_list = 'lib/tasks/test_affiliations.csv'

  # update works with allied health affiliation
  File.readlines(record_list).each_with_index do |line, index|
    # if index < 5
      model, id = line.split(',').collect(&:strip)
      work = ActiveFedora::Base.find(id)
      people.each do |person|
        if  work.attributes.keys.member?(person)
          if !work[person].blank?
            # Only update records if there are changes
            update = false
            # Keep track of people for resubmission in case update is needed
            tmp_people = Hash.new
            work[person].each_with_index do |p, i|
              # Store person information hash in case record needs to be updated
              tmp_people["#{i}"] = JSON.parse(p.to_json)
              # Check if affiliation includes allied health affiliation
              allied_health_department = (JSON.parse(p.affiliation.to_json) & ['Curriculum in Human Movement Science',
                                                                               'Clinical Laboratory Science',
                                                                               'Clinical Rehabilitation and Mental Health Counseling',
                                                                               'Division of Occupational Science',
                                                                               'Division of Occupational Science and Occupational Therapy',
                                                                               'Division of Physical Therapy', 'Division of Radiologic Science',
                                                                               'Division of Speech and Hearing Sciences',
                                                                               'Physician Assistant Program',
                                                                               'Department of Allied Health Sciences'])
              puts allied_health_department
              if !allied_health_department.empty?
                update = true
                tmp_people["#{i}"]['affiliation'] = allied_health_department - ['Department of Allied Health Sciences']
              end
            end
            if update
              # Not working
              # raw_params = JSON.parse(work.to_json)
              # raw_params[person.to_s+'_attributes'] = tmp_people
              # work.attributes = raw_params.delete('id')
              # work.save!

              # Also not working
              # update_hash = {}
              # update_hash[person.to_s+'_attributes'] = tmp_people
              # work.update(update_hash)

              # Also not working
              # work.update((person.to_s+'_attributes') => tmp_people)
            end
          end
        end
      end
    # end
  end
end
