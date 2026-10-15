# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v5.3.0/app/helpers/hyrax/hyrax_helper_behavior.rb

Hyrax::HyraxHelperBehavior.module_eval do
  def available_admin_sets_for_creating_works(ability:)
    return [] unless Flipflop.assign_admin_set?
    return [] unless ability

    source_ids = Hyrax::Collections::PermissionsService.source_ids_for_deposit(
      ability: ability,
      source_type: 'admin_set'
    )
    return [] if source_ids.blank?

    # [hyc-override] Avoid Wings `find_many_by_ids`, which resolves each admin set via Fedora one id at a time.
    admin_sets_list = Hyrax::SolrQueryService.new
                        .with_ids(ids: source_ids)
                        .with_field_pairs(
                          field_pairs: {
                            has_model_ssim: Hyrax::ModelRegistry.admin_set_rdf_representations.join(',')
                          },
                          type: 'terms'
                        )
                        .solr_documents(rows: source_ids.length, fl: 'id,title_tesim')
                        .map do |doc|
      [Array(doc['title_tesim']).first.to_s, doc['id']]
    end

    admin_sets_list.sort do |a, b|
      if Hyrax::AdminSetCreateService.default_admin_set?(id: a[1])
        -1
      elsif Hyrax::AdminSetCreateService.default_admin_set?(id: b[1])
        1
      else
        a[0] <=> b[0]
      end
    end
  end
end
