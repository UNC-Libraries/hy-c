desc "Mint and add UNC Library DOIs to records that don't have them"
task :add_dois, [:rows] => :environment do |_t, args|
  add_dois = Tasks::DoiCreateService.new(args[:rows])
  add_dois.create_batch_doi
end
