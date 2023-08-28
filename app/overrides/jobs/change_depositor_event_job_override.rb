# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/jobs/change_depositor_event_job.rb
Hyrax::ChangeDepositorEventJob.class_eval do
  # [hyc-override] Overriding to make depositor a facet search and not link to user profile
  def action
    proxy_link = link_to(repo_object.proxy_depositor, search_catalog_path(f: { depositor_ssim: [repo_object.proxy_depositor] }))
    new_user_link = link_to(depositor, search_catalog_path(f: { depositor_ssim: [depositor] }))
    "User #{proxy_link} has transferred #{link_to_work repo_object.title.first} to user #{new_user_link}"
  end
end