# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight/blob/v7.33.1/app/components/blacklight/facet_field_pagination_component.rb
Blacklight::FacetFieldPaginationComponent.class_eval do
    def dept_paginate(facet_paginator, rows: 10, page_param: :page)
        return if facet_paginator.nil?
        Rails.logger.info('D12 - Not Nil Paginator')

        items = facet_paginator.instance_variable_get(:@all)
        return if items.nil? || items.empty?
        Rails.logger.info('D12 - Not Nil Items')
      
        total_count = items.size
        total_pages = (total_count.to_f / rows.to_f).ceil
        page = params[page_param].presence&.to_i || 1
        current_page = [page, total_pages].min
        Rails.logger.info("tc: #{total_count}")
        Rails.logger.info("tp: #{total_pages}")
        Rails.logger.info("p: #{current_page}")
      
        Kaminari.paginate_array(items, total_count: total_count).page(current_page).per(rows)
    end
end