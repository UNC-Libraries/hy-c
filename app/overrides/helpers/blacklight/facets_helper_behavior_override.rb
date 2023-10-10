# [hyc-override] https://github.com/projectblacklight/blacklight/blob/v7.33.1/app/helpers/blacklight/facets_helper_behavior.rb
Blacklight::FacetsHelperBehavior.module_eval do
  # [hyc-override] make the list of facet fields unique to prevent duplicate Date facet
  alias_method :original_render_facet_partials, :render_facet_partials
  def render_facet_partials fields = nil, options = {}
    original_render_facet_partials(fields&.uniq, options)
  end
end