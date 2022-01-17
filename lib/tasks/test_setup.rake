desc "Sets up testing environment"
task test_setup: :environment do
  Rake::Task['db:migrate'].invoke
  puts 'ran migrations'
  Rake::Task['setup:admin_role'].invoke
  puts 'created admin user and role'
  Rake::Task['setup:test_data_import'].invoke
  puts 'created test data'
end
