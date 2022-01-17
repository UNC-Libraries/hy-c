desc "Updates URL for DOI records"
task :update_doi_urls, [:state, :rows, :retries, :end_date, :log_dir] => :environment do |_t, args|
  log = ActiveSupport::Logger.new("#{args[:log_dir]}/update_doi_#{Time.now.strftime('%Y%m%d%H%M%S')}.log")
  Tasks::UpdateDoiUrlsService.new(args, log).update_dois
end
