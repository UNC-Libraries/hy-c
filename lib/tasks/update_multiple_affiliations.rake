desc "Remediate records with multiple affiliations, leaving only the most specific affiliation"
task :update_multiple_affiliations, [:id_list_path] => :environment do |t, args|
  top_level_affiliations = [
      'Gillings School of Global Public Health',
      'School of Medicine',
      'College of Arts and Sciences',
      'Eshelman School of Pharmacy',
      'School of Dentistry'
  ]
  people = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
            'reviewers', 'translators']

  CSV.foreach(args[:id_list_path]) do |record|
    begin
      work = ActiveFedora::Base.find(record[0])
    rescue
      Rails.logger.warn "Could not find matching work for id: #{record[0]}"
      next
    end

    people.each do |person|
      if work.attributes.keys.member?(person)
        unless work[person].blank?
          work[person].each do |p|
            final_affiliation = nil
            match_length = 0
            affiliations_to_delete = []

            affiliations = record[2].split('||')
            affiliations_left = affiliations.length
            affil_vals = JSON.parse(p.affiliation.to_json)

            affil_vals.each do |aff|
              if affiliations_left == 1
                final_affiliation = aff
                break
              end

              if top_level_affiliations.include? aff
                affiliations_to_delete.push(aff)
                affiliations_left -= 1
                next
              end

              if affiliations_left >= 2
                labels = DepartmentsService.label_matches(aff)

                unless labels.blank?
                  label_matches = []
                  labels.each do |l|
                    lab = l.map { |st| st.strip }

                    if aff == lab.last
                      label_matches << lab
                    end
                  end

                  if label_matches.length >= 1
                    correct_label_list = labels.sort_by{|d| -d.length }.first
                    correct_label_list_size = correct_label_list.length
                    correct_label = correct_label_list.last.strip

                    if correct_label_list_size > match_length
                      if !final_affiliation.nil? && aff != final_affiliation
                        affiliations_to_delete.push(final_affiliation)
                      end

                      match_length = correct_label_list_size
                      final_affiliation = aff
                      next
                    end

                    if aff != correct_label
                      affiliations_to_delete.push(aff)
                      affiliations_left -= 1
                    end
                  else
                    affiliations_to_delete.push(aff)
                    affiliations_left -= 1
                  end
                end
              end

              unless affiliations_to_delete.blank?
                affiliations_to_delete.each do |d_aff|
                  Rails.logger.info "Deleting #{d_aff} for #{person} in work: #{record[0]}"
                  p.affiliation.delete(d_aff)
                end
              end
            end
          end
        end
      end
    end
    work.save!
    Rails.logger.info "Updates complete for work: #{record[0]}"
  end
end