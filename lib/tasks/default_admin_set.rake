desc "Adds default admin set to hyrax application"
task :default_admin_set => :environment do
  Hyrax::AdminSetCreateService.call(admin_set: AdminSet.new(title: ['default']),
                                    creating_user: User.where(email: 'admin@example.com').first)
end
