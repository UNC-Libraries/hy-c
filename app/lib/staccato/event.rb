# [hyc-override] Overriding staccato gem to allow hostname as a field.
module Staccato
  # Event Hit type field definitions
  # @author Tony Pitale
  class Event
    # Event field definitions
    FIELDS = {
      category: 'ec',
      action: 'ea',
      label: 'el',
      value: 'ev',
      hostname: 'dh'
    }

    include Hit

    # event hit type
    def type
      :event
    end
  end
end
