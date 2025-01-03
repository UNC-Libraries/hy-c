# frozen_string_literal: true
# [hyc-override] https://github.com/kaminari/kaminari/blob/v1.2.2/kaminari-core/lib/kaminari/helpers/helper_methods.rb
Kaminari::Helpers::HelperMethods.module_eval do
    # Helper to generate a link to a specific page
  def link_to_specific_page(scope, name, page, total_pages, **options)
    begin
      # Validate inputs
    #   raise ArgumentError, 'Scope is required and must respond to :total_pages' unless scope&.respond_to?(:total_pages)
      raise ArgumentError, "Page number must be a positive integer - got #{page}" unless page.is_a?(Integer) && page.positive?

      specific_page_path = path_to_specific_page(scope, page, total_pages, options)

      # Remove the :params and :param_name keys from the options hash before generating the link since they are irrelevant
      options.except! :params, :param_name

      # Setting aria instead of rel for accessibility
      options[:aria] ||= { label: "Go to page #{page}" }

      if specific_page_path
        link_to(name || page, specific_page_path, options)
      elsif block_given?
        yield
      else
        Rails.logger.warn "Specific page path could not be generated for page: #{page}"
        nil
      end
    rescue ArgumentError => e
      Rails.logger.error "Error in link_to_specific_page: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Unexpected error in link_to_specific_page: #{e.message}"
      nil
    end
  end

    # Helper to generate the path for a specific page
  def path_to_specific_page(scope, page, total_pages, options = {})
    begin
      # Calculate total pages manually
    #   total_items = scope.instance_variable_get(:@all).size
    #   limit = scope.instance_variable_get(:@limit)
    #   total_pages = (total_items.to_f / limit).ceil

      Rails.logger.info "path_to_specific_page: total_items=#{total_items}, limit=#{limit}, calculated total_pages=#{total_pages}, page=#{page}"

      # Validate inputs
      raise ArgumentError, 'Page number must be a positive integer' unless page.is_a?(Integer) && page.positive?
      raise ArgumentError, "Page number exceeds total pages (#{total_pages})" if page > total_pages
      # Generate URL using Kaminari's Page helper
      Kaminari::Helpers::Page.new(self, **options.reverse_merge(page: page)).url
    rescue ArgumentError => e
      Rails.logger.info "Error in path_to_specific_page: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Unexpected error in path_to_specific_page: #{e.message}\n#{e.backtrace.join("\n")}"
      nil
    end
  end
end
