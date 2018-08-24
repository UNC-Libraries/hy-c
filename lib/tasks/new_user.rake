desc "Adds generic user to hyrax application"
task :new_user => :environment do
  User.first_or_create(email: 'person@example.com',
              password: 'password',
              password_confirmation: 'password',
              uid: 'person@example.com')
end
