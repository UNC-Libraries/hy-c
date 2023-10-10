# [hyc-override] https://github.com/sul-dlss/SearchWorks/blob/01b8a0e8502220d4775ea868b097e9c723756455/app/components/advanced_search_range_limit_component.rb
# The file is unchanged, but is imported from another project
class AdvancedSearchRangeLimitComponent < ViewComponent::Base
  def initialize(facet_field:, **kwargs)
    @facet_field = facet_field
  end
end