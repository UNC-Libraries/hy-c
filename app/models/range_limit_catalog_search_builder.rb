class RangeLimitCatalogSearchBuilder < Hyrax::CatalogSearchBuilder
  include BlacklightRangeLimit::RangeLimitBuilder
end