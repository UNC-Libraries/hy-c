# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/controllers/hyrax/stats_controller.rb
Hyrax::StatsController.class_eval do
  def work
    # [hyc-override] modified to include daily page views and custom download event
    @document = ::SolrDocument.find(params[:id])
    @pageviews = Hyrax::Analytics.daily_events_for_id(@document.id, 'work-view','last30')
    @downloads = Hyrax::Analytics.daily_events_for_id(@document.id, 'DownloadIR','last30')
  end
end
