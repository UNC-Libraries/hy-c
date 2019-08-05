desc "Mint and add UNC Library DOIs to records that don't have them"
task :add_dois, [:rows, :use_test_api] => :environment do |t, args|
  add_dois = Hyc::DoiCreate.new(args[:rows], args[:use_test_api])
  add_dois.create_batch_doi
end