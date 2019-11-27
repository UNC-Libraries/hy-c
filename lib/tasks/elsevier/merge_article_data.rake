require 'tasks/migrate/services/progress_tracker'

desc "Merge and dedup scopus and web of science data"
task :merge_article_data => :environment do
  # Progress tracker for objects checked
  wos_progress = Migrate::Services::ProgressTracker.new('lib/tasks/elsevier/wos_progress.log')
  scopus_progress = Migrate::Services::ProgressTracker.new('lib/tasks/elsevier/scopus_progress.log')

  wos_data = CSV.read('lib/tasks/elsevier/web_of_science_2018_full.csv', headers: true)
  scopus_data = CSV.read('lib/tasks/elsevier/scopus.csv', headers: true)

  puts wos_data.count
  puts scopus_data.count

  # wos_completed = wos_progress.completed_set
  # scopus_completed = scopus_progress.completed_set
  #
  # wos_data.delete_if {|row| wos_completed.include?(row['UT'])}
  # scopus_data.delete_if {|row| scopus_completed.include?(row['EID'])}
  #
  # count = 0 # number of WoS articles not found in scopus set
  # wos_data.each_with_index do |wos_row, index|
  #   if index % 500 == 0
  #     puts "#{index} records checked"
  #   end
  #
  #   scopus_record = scopus_data.find{|row| row['DOI'] == wos_row['DI']}
  #
  #   if scopus_record.blank?
  #     scopus_record_title = scopus_data.find{|row| row['Title'] == wos_row['TI']}
  #     if scopus_record_title.blank?
  #       puts "no scopus record for #{wos_row['UT']}"
  #       count += 1
  #     else
  #       scopus_progress.add_entry scopus_record_title['EID']
  #     end
  #   else
  #     scopus_progress.add_entry scopus_record['EID']
  #   end
  #   wos_progress.add_entry wos_row['UT']
  # end
  #
  # scopus_completed = scopus_progress.completed_set
  # scopus_data.delete_if {|row| scopus_completed.include?(row['EID'])}
  #
  # puts "#{scopus_data.count} scopus records remaining"
  # puts "#{count} web of science records not in scopus"
  #
  # # put leftover scopus record in new csv
  # CSV.open('lib/tasks/elsevier/scopus_remaining_2018-3.csv', 'a+') do |csv|
  #   scopus_data.each do |data|
  #     csv << data
  #   end
  # end
end
