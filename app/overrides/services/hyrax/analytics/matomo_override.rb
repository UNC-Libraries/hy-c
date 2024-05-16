# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/services/hyrax/analytics/matomo.rb
Hyrax::Analytics::Matomo.module_eval do
  class_methods do
    # [hyc-override] added method for getting monthly stats
    # Pass in an action name and an id and get back the monthly count of events for that id. [date, event_count]
    def monthly_events_for_id(id, action, date = default_date_range)
      additional_params = {
        flat: 1,
        label: "#{id} - #{action}"
      }
      response = api_params('Events.getName', 'month', date, additional_params)
      results_array(response, 'nb_events')
    end
  end
end