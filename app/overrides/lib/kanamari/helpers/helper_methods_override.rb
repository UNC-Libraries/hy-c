# frozen_string_literal: true
# [hyc-override] https://github.com/kaminari/kaminari/blob/v1.2.2/kaminari-core/lib/kaminari/helpers/helper_methods.rb
Kaminari::Helpers::HelperMethods.module_eval do
    # Helper to generate a link to a specific page
  def link_to_specific_page(scope, page, name, **options)
    specific_page_path = path_to_specific_page(scope, page, options)

    # Remove the :params and :param_name keys from the options hash before generating the link since they are irrelevant
    options.except! :params, :param_name

    # Setting aria instead of rel for accessibility
    options[:aria] ||= { label: "Go to page #{page}" }

    if specific_page_path
      link_to(name || page, specific_page_path, options)
    elsif block_given?
      yield
    end
  end

    # Helper to generate the path for a specific page
  def path_to_specific_page(scope, page, options = {})
    Kaminari::Helpers::Page.new(self, **options.reverse_merge(current_page: page)).url if page.positive? && page <= scope.total_pages
  end
end
