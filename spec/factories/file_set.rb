# spec/factories/file_set.rb
FactoryBot.define do
  factory :file_set do
    transient do
      user { FactoryBot.create(:user) }
      content { nil }
    end
  end
end
