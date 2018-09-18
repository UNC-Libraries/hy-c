desc "Sets up testing environment"
task :test_setup => :environment do
  Rake::Task['db:migrate'].invoke
  Rake::Task['admin_role'].invoke
  Rake::Task['test_data_import'].invoke
end