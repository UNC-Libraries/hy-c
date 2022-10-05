# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v2.9.6/app/jobs/content_restored_version_event_job.rb
Hyrax::ContentRestoredVersionEventJob.class_eval do
  # [hyc-override] Overriding to make depositor a facet search and not link to user profile
  def action
    "User #{link_to depositor, search_catalog_path(f: { depositor_ssim: [depositor] })} has restored a version '#{revision_id}' of #{link_to repo_object.title.first, Rails.application.routes.url_helpers.hyrax_file_set_path(repo_object)}"
  end
end
