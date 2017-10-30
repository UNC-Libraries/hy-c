desc "Sets up testing environment"
task :test_setup => :environment do
  Rake::Task['db:migrate'].invoke
  Rake::Task['admin_role'].invoke
  Rake::Task["cdr:migration:items"].invoke('lib/tasks/migration/tmp')
end