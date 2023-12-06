# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/controllers/hyrax/stats_controller.rb
Hyrax::StatsController.class_eval do
  def work
    # [hyc-override] temporarily return a 404 until the GA4 stats implementation is complete
    head :not_found
  end

  def file
    # [hyc-override] temporarily return a 404 until the GA4 stats implementation is complete
    head :not_found
  end
end
