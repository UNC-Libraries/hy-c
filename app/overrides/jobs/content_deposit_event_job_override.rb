# frozen_string_literal: true
# [hyc-override] Overriding to make depositor a facet search and not link to user profile
# https://github.com/samvera/hyrax/blob/v2.9.6/app/jobs/content_deposit_event_job.rb
Hyrax::ContentDepositEventJob.class_eval do
  def action
    "User #{link_to depositor, search_catalog_path(f: { depositor_ssim: [depositor] })} has deposited #{link_to repo_object.title.first, polymorphic_path(repo_object)}"
  end
end
