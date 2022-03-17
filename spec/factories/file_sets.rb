# frozen_string_literal: true

# from https://github.com/samvera/hyrax/blob/b034218b89dde7df534e32d1e5ade9161e129a1d/spec/factories/file_sets.rb#L35
FactoryBot.define do
  factory :file_set do
    transient do
      user { create(:user) }
      content { nil }
    end
    after(:build) do |fs, evaluator|
      fs.apply_depositor_metadata evaluator.user.user_key
    end

    after(:create) do |file, evaluator|
      Hydra::Works::UploadFileToFileSet.call(file, evaluator.content) if evaluator.content
    end

    trait :public do
      read_groups { ['public'] }
    end

    trait :registered do
      read_groups { ['registered'] }
    end

    trait :image do
      content { File.open("#{RSpec.configuration.fixture_path}/files/image.png") }
    end

    trait :with_malformed_pdf do
      after(:create) do |file_set, _evaluator|
        Hydra::Works::AddFileToFileSet
          .call(file_set, File.open("#{RSpec.configuration.fixture_path}/files/1022-0.pdf"), :original_file)
      end
    end

    trait :with_original_file do
      after(:create) do |file_set, _evaluator|
        Hydra::Works::AddFileToFileSet
          .call(file_set, File.open("#{RSpec.configuration.fixture_path}/files/image.png"), :original_file)
      end
    end

    trait :with_original_pdf_file do
      after(:create) do |file_set, _evaluator|
        Hydra::Works::AddFileToFileSet
          .call(file_set, File.open("#{RSpec.configuration.fixture_path}/files/sample_pdf.pdf"), :original_file)
      end
    end

    trait :with_original_docx_file do
      after(:create) do |file_set, _evaluator|
        Hydra::Works::AddFileToFileSet
          .call(file_set, File.open("#{RSpec.configuration.fixture_path}/files/sample_docx.docx"), :original_file)
      end
    end

    trait :with_original_msword_file do
      after(:create) do |file_set, _evaluator|
        Hydra::Works::AddFileToFileSet
          .call(file_set, File.open("#{RSpec.configuration.fixture_path}/files/sample_msword.docx"), :original_file)
      end
    end

    trait :with_extracted_text do
      after(:create) do |file_set, _evaluator|
        Hydra::Works::AddFileToFileSet
          .call(file_set, File.open("#{RSpec.configuration.fixture_path}/files/sample_pdf.pdf"), :original_file)
        Hydra::Works::AddFileToFileSet
          .call(file_set, File.open("#{RSpec.configuration.fixture_path}/files/test.txt"), :extracted_text)
      end
    end

    factory :file_with_work do
      after(:build) do |file, _evaluator|
        file.title = ['testfile']
      end
      after(:create) do |file, evaluator|
        Hydra::Works::UploadFileToFileSet.call(file, evaluator.content) if evaluator.content
        create(:work, user: evaluator.user).members << file
      end
    end
  end
end
