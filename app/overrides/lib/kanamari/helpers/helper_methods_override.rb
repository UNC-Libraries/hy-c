# frozen_string_literal: true
# [hyc-override] https://github.com/kaminari/kaminari/blob/v1.2.2/kaminari-core/lib/kaminari/helpers/helper_methods.rb
Kaminari::Helpers::HelperMethods.module_eval do
    # Helper to generate a link to a specific page
  def link_to_specific_page(scope, page, total_entries, **options)
    begin
      specific_page_path = path_to_specific_page(scope, page.to_i, total_entries, options)

      # Remove unnecessary keys :params and :param_name from the options hash before generating the link
      options.except! :params, :param_name

      # Setting aria instead of rel for accessibility
      options[:aria] ||= { label: "Go to page #{page.to_i}" }

      if specific_page_path
        link_to("#{page.to_i}" || page.to_i, specific_page_path, options)
      else
        Rails.logger.warn "Specific page path could not be generated for page: #{page.to_i}"
        nil
      end
    rescue => e
      Rails.logger.error "#{e.message}"
      nil
    end
  end

    # Helper to generate the path for a specific page
  def path_to_specific_page(scope, page_integer, total_entries, options = {})
    begin
      # Calculate total pages manually
      limit = scope.instance_variable_get(:@limit)
      total_pages = (total_entries.to_f / limit).ceil

      Rails.logger.debug "path_to_specific_page: total_entries=#{total_entries}, limit=#{limit}, calculated total_pages=#{total_pages}, page=#{page_integer}"

      # Validate inputs
      raise ArgumentError, 'Page number must be a positive integer' unless page_integer.positive?
      raise ArgumentError, "Page number exceeds total pages (#{total_pages})" if page_integer > total_pages
      # Generate URL using Kaminari's Page helper
      Kaminari::Helpers::Page.new(self, **options.reverse_merge(page: page_integer)).url
    rescue ArgumentError => e
      Rails.logger.error "Error in path_to_specific_page: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Unexpected error in path_to_specific_page: #{e.message}\n#{e.backtrace.join("\n")}"
      nil
    end
  end
end
