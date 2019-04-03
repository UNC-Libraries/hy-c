FactoryBot.define do
  factory :user do
    uid { 'test' }
    display_name { 'test' }
    email { 'test@test.edu' }

    transient do
      # Allow for custom groups when a user is instantiated.
      # @example FactoryBot.create(:user, groups: 'admin')
      groups { [] }
    end

    factory :admin do
      groups { ['admin'] }

      after(:create) do |user, evaluator|
        role = Role.find_or_create_by(name: 'admin')
        role.users << user
        role.save
      end
    end
  end
end
