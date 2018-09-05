desc "Adds generic user to hyrax application"
task :new_user => :environment do
  User.where(email: 'person@example.com', uid: 'person@example.com')
      .first_or_create(password: 'password', password_confirmation: 'password')
end
