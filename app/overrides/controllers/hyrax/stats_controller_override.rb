# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/controllers/hyrax/stats_controller.rb
Hyrax::StatsController.class_eval do
  def work
    @document = ::SolrDocument.find(params[:id])
    @pageviews = Hyrax::Analytics.daily_events_for_id(@document.id, 'work-view')
    # [hyc-override] Pull DownloadIR stats from the first 100 filesets in the work
    work = ActiveFedora::Base.find(params[:id])
    fileset_ids = work.members.first(100).map(&:id)
    combined_results = nil
    fileset_ids.each do |fileset_id|
      events = Hyrax::Analytics.daily_events_for_id(fileset_id, 'download-ir')
      if combined_results.nil?
        combined_results = events
      else
        # Merge incoming event counts into the combined result.
        # Results values are lists containing 2 elements, the date and the event count.
        events.results.each_with_index do |entry, index|
          combined_results.results[index][1] += entry[1]
        end
      end
    end
    @downloads = combined_results
  end
end
