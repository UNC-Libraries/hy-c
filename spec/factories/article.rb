# frozen_string_literal: true
FactoryBot.define do
  factory :article do
    id { Noid::Rails::Service.new.mint }
    title { [] << 'No Embargo' }
    visibility { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC }

    transient do
      user { nil }
    end

    factory :tomorrow_expiration do
      embargo { FactoryBot.create(:embargo, embargo_release_date: Time.zone.tomorrow) }
    end
  end
end
