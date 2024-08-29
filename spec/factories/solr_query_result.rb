# spec/factories/solr_query_result.rb
# frozen_string_literal: true

# Helper method to generate work or admin IDs like '0001abc', '0002abc', etc.
def generate_id(n)
  "#{n.to_s.rjust(4, '0')}abc"
end

# Factory for creating Solr query results
FactoryBot.define do
  factory :solr_query_result, class: OpenStruct do
    trait :work do
      # Default values for has_model_ssim, admin_set_tesim, and file_set_ids_ssim
      has_model_ssim { ['Article'] }
      admin_set_tesim { ['Open_Access_Articles_and_Book_Chapters'] }
      file_set_ids_ssim { ['file_set_id'] }
      sequence(:id) { |n| generate_id(n) }
      sequence(:title_tesim) { |n| ["Test Title #{n}"] }
    end

    trait :admin_set do
      # Default values for has_model_ssim and title_tesim
      has_model_ssim { ['AdminSet'] }
      title_tesim { ['Open_Access_Articles_and_Book_Chapters'] }
      sequence(:id) { |n| generate_id(n) }
    end

    # Override the default save behavior to do nothing since it's a non-ActiveRecord object
    to_create { |instance| instance }
  end
end
