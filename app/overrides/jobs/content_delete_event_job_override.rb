# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v2.9.6/app/jobs/content_delete_event_job.rb
Hyrax::ContentDeleteEventJob.class_eval do
  # [hyc-override] Overriding to make depositor a facet search and not link to user profile
  def action
    @action ||= "User #{link_to depositor, search_catalog_path(f: { depositor_ssim: [depositor] })} has deleted object '#{deleted_work_id}'"
  end
end
