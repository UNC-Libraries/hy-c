# frozen_string_literal: true
# [hyc-override] Overriding to not make depositor a clickable link
# https://github.com/samvera/hyrax/blob/v2.9.6/app/jobs/file_set_attached_event_job.rb
Hyrax::FileSetAttachedEventJob.class_eval do
  def action
    "User #{link_to depositor, search_catalog_path(f: { depositor_ssim: [depositor] })} has attached #{file_link} to #{work_link}"
  end
end
