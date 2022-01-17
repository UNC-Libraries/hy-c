require 'tasks/migrate/services/progress_tracker'

desc 'Check all record, fileset, and download links for restricted works'
task :check_restricted_routes, [:start, :rows, :log_dir] => :environment do |_t, args|
  puts "[#{Time.now}] starting check"

  model_map = { 'Article' => 'article',
                'Artwork' => 'artwork',
                'DataSet' => 'data_set',
                'Dissertation' => 'dissertation',
                'General' => 'general',
                'HonorsThesis' => 'honors_thesis',
                'Journal' => 'journal',
                'MastersPaper' => 'masters_paper',
                'Multimed' => 'multimed',
                'ScholarlyWork' => 'scholarly_work',
                'FileSet' => 'file_set',
                'Collection' => 'collection' }

  # Progress tracker for objects checked
  restricted_item_progress = Migrate::Services::ProgressTracker.new("#{args[:log_dir]}/restricted_item_progress.log")
  restricted_item_error_progress = Migrate::Services::ProgressTracker.new("#{args[:log_dir]}/restricted_item_error_progress.log")
  checked = restricted_item_progress.completed_set + restricted_item_error_progress.completed_set

  restricted_item_query = ActiveFedora::SolrService.get('(visibility_ssi:authenticated OR visibility_ssi:restricted) AND has_model_ssim:(Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork FileSet)',
                                                        sort: 'system_create_dtsi ASC',
                                                        start: args[:start],
                                                        rows: args[:rows],
                                                        fl: 'id,has_model_ssim')['response']
  restricted_item_count = restricted_item_query['numFound']
  puts restricted_item_count

  restricted_items = restricted_item_query['docs']
  puts restricted_items.count

  # iterate through each
  restricted_items.each do |restricted_item|
    if checked.include? restricted_item['id']
      puts "already checked #{restricted_item['id']}"
      next
    end

    # generate record link for each
    show_page_url = Rails.application.routes.url_helpers.send("hyrax_#{model_map[restricted_item['has_model_ssim'].first]}_url", restricted_item['id'])
    puts show_page_url

    page_response = HTTParty.get(show_page_url)
    unless page_response.response.body.match('Single Sign-On')
      puts "#{restricted_item['id']} show page is open"
      restricted_item_error_progress.add_entry(restricted_item['id'])
      next
    end

    # generate download link for files
    if restricted_item['has_model_ssim'].first == 'FileSet'
      download_url = "#{ENV['HYRAX_HOST']}/downloads/#{restricted_item['id']}"
      puts download_url

      page_response = HTTParty.get(download_url)
      if page_response.response.code.to_i == 200 && !page_response.response.body.match('Single Sign-On')
        puts "#{restricted_item['id']} download link is open"
        restricted_item_error_progress.add_entry(restricted_item['id'])
        next
      end
    end

    restricted_item_progress.add_entry(restricted_item['id'])
  end

  puts "#{Time.now} done."
end
