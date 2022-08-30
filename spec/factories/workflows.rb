# frozen_string_literal: true
# From https://github.com/samvera/hyrax/blob/v2.9.6/spec/factories/workflows.rb
FactoryBot.define do
  factory :workflow, class: Sipity::Workflow do
    sequence(:name) { |n| "generic_work-#{n}" }
    permission_template
  end
end
