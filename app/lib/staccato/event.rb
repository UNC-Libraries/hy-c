# frozen_string_literal: true
# [hyc-override] Overriding staccato gem to allow hostname as a field.
module Staccato
  # Event Hit type field definitions
  # @author Tony Pitale
  # See https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
  class Event
    # Event field definitions
    FIELDS = {
      category: 'ec',
      action: 'ea',
      label: 'el',
      value: 'ev',
      hostname: 'dh',
      referrer: 'dr',
      data_source: 'ds'
    }

    include Hit

    # event hit type
    def type
      :event
    end
  end
end
