# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/hyrax/stats_controller.rb
Hyrax::StatsController.class_eval do
  def work
    # [hyc-override] different parameters and switched to using monthly instead of daily events
    @document = ::SolrDocument.find(params[:id])
    # [hyc-override] Execute all of the matomo requests in parallel
    threads = []
    threads << Thread.new do
      @pageviews = Hyrax::Analytics.monthly_events_for_id(@document.id, 'work-view')
    end
    # [hyc-override] Pull DownloadIR stats from the first 100 filesets in the work
    work = ActiveFedora::Base.find(params[:id])
    fileset_ids = work.members.first(100).map(&:id)
    combined_results = nil
    mutex = Mutex.new

    fileset_ids.each do |fileset_id|
      threads << Thread.new do
        events = Hyrax::Analytics.monthly_events_for_id(fileset_id, 'DownloadIR')
        mutex.synchronize do
          if combined_results.nil?
            combined_results = events
          else
            # Merge incoming event counts into the combined result.
            # Results values are lists containing 2 elements, the date and the event count.
            events.results.each_with_index do |entry, index|
              next if entry.nil?
              combined_results.results[index][1] += entry[1]
            end
          end
        end
      end
    end
    threads.each(&:join)
    @downloads = combined_results
  end
end
