# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v2.9.6/app/jobs/content_depositor_change_event_job.rb
# TODO class was deleted in hyrax 4.0.0
# Hyrax::ContentDepositorChangeEventJob.class_eval do
#   # [hyc-override] Overriding to make depositor a facet search and not link to user profile
#   def action
#     proxy_link = link_to(work.proxy_depositor, search_catalog_path(f: { depositor_ssim: [work.proxy_depositor] }))
#     new_user_link = link_to(depositor, search_catalog_path(f: { depositor_ssim: [depositor] }))
#     "User #{proxy_link} has transferred #{link_to_work work.title.first} to user #{new_user_link}"
#   end
# end
