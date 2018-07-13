desc "Adds generic admin role to hyrax application"
task :admin_role => :environment do
  User.create(email: 'admin@example.com',
              password: 'password',
              password_confirmation: 'password',
              uid: 'admin@example.com')
  admin = Role.create(name: 'admin')
  admin.users << User.find_by_user_key('admin@example.com')
  admin.save
end