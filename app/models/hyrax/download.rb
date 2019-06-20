module Hyrax
  class Download
    extend ::Legato::Model

    metrics :totalEvents
    dimensions :eventCategory, :eventAction, :eventLabel, :date
    filter :for_file, &->(id) { contains(:eventLabel, id) }
  end
end
