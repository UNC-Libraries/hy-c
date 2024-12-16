# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight/blob/v7.33.1/app/components/blacklight/facet_field_pagination_component.rb
Blacklight::FacetFieldPaginationComponent.class_eval do
    # Converts a `Blacklight::Solr::FacetPaginator` to `Kaminari::PaginatableArray` to enable pagination utilizing Kaminari gem
    # Based on `paginate` in Hyrax::Admin::Analytics::AnalyticsController
    # https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/hyrax/admin/analytics/analytics_controller.rb
  def convert_facet_to_paginated_array(facet_paginator, rows: 10, page_param: :page)
    return if facet_paginator.nil?
      # Retrieve all items
    items = facet_paginator.instance_variable_get(:@all)
    return if items.nil? || items.empty?

    total_count = items.size
      # Calculate the total number of pages based on the number of rows per page
    total_pages = (total_count.to_f / rows.to_f).ceil
      # Extract the current page number from the response params, defaulting to 1 if not present
    page = params[page_param].presence&.to_i || 1
      # Ensure the current page does not exceed the total number of pages
    current_page = [page, total_pages].min

      # Use Kaminari to create a paginated collection from the items array
      # `.page(current_page)` sets the current page
      # `.per(rows)` sets the number of items to display per page
    Kaminari.paginate_array(items, total_count: total_count).page(current_page).per(rows)
  end
end
