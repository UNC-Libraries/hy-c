# frozen_string_literal: true
# [hyc-override] filter ga stats by old and new ids
module Hyrax
  class Download
    extend ::Legato::Model

    metrics :totalEvents
    dimensions :eventCategory, :eventAction, :eventLabel, :date
    filter :for_file, &->(id) { contains(:eventLabel, id) }
  end
end
