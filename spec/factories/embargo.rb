FactoryBot.define do
  factory :embargo, class: Hydra::AccessControls::Embargo do
    visibility_during_embargo { 'restricted' }
    visibility_after_embargo { 'open' }
    embargo_release_date { '2017-07-04 00:00:00' }
  end
end
