module Hyrax
  class Download
    extend ::Legato::Model

    metrics :totalEvents
    dimensions :eventCategory, :eventAction, :eventLabel, :date
    filter :for_file, &->(ids) { ids.map { |id| matches(:eventLabel, id) } }
  end
end
