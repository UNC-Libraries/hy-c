# frozen_string_literal: true
# spec/factories/hyc_download_stats.rb
FactoryBot.define do
  factory :hyc_download_stat do
    sequence(:fileset_id) { |n| n.to_s }
    sequence(:work_id) { |n| n.to_s }
    sequence(:admin_set_id) { |n| n.to_s }
    sequence(:work_type) { |n| n.to_s }
    date { Date.today }
    download_count { 0 }
  end
end
