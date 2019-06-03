desc "Adds generic admin role to hyrax application"
task :admin_role => :environment do
  User.where(email: 'admin@example.com', uid: 'admin')
          .first_or_create(password: 'password', password_confirmation: 'password')
  admin = Role.where(name: 'admin').first_or_create
  admin.users << User.find_by_user_key('admin')
  admin.save
end