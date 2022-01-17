namespace 'setup' do
  desc "Adds generic admin role to hyrax application"
  task admin_role: :environment do
    Tasks::SetupTasksService.admin_role
  end

  desc "Adds default admin set to hyrax application"
  task default_admin_set: :environment do
    Tasks::SetupTasksService.default_admin_set
  end

  desc "Adds generic user to hyrax application"
  task :new_user, [:email] => :environment do |_t, args|
    Tasks::SetupTasksService.new_user(args[:email])
  end

  desc "Adds sample data for oai tests"
  task test_data_import: :environment do
    Tasks::SetupTasksService.test_data_import
  end
end
