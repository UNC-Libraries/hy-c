# frozen_string_literal: true
FactoryBot.define do
  factory :file_download_stat do
    sequence(:id) { |n| n }  # Auto-incrementing ID
    date { FFaker::Time.between(Date.new(2019, 1, 1), Date.new(2024, 12, 31)) }  # Random date between a range
    downloads { rand(1..50) }
    sequence(:file_id) { |n| "file_id_#{n}" }  # Unique file ID for each record
    created_at { date }
    updated_at { date }
    user_id { rand(1..100) }
  end
end
