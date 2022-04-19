FactoryBot.define do
  factory :user do
    # Onyens are any 3-8 character alphanumeric string beginning with a letter - we are using the uid field to hold they onyen
    uid { FFaker::InternetSE.user_name_variant_short }
    display_name { FFaker::Name.name }
    email { FFaker::Internet.email }

    transient do
      # Allow for custom groups when a user is instantiated.
      # @example FactoryBot.create(:user, groups: 'admin')
      groups { [] }
    end

    factory :admin do
      groups { ['admin'] }

      after(:create) do |user, _evaluator|
        role = Role.find_or_create_by(name: 'admin')
        role.users << user
        role.save
      end
    end
  end
end
