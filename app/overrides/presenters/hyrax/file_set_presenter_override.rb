# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/presenters/hyrax/file_set_presenter.rb
Hyrax::FileSetPresenter.class_eval do
  def fetch_parent_presenter
    # [hyc-override] set a rows field to avoid warnings about no rows being explicitly set
    ids = Hyrax::SolrService.query("{!field f=member_ids_ssim}#{id}", fl: Hyrax.config.id_field, rows: 10)
                            .map { |x| x.fetch(Hyrax.config.id_field) }
    Hyrax.logger.warn("Couldn't find a parent work for FileSet: #{id}.") if ids.empty?
    ids.each do |id|
      doc = ::SolrDocument.find(id)
      next if current_ability.can?(:edit, doc)
      # [hyc-override] throw exception when suppressed if user CANNOT read the doc, rather than if they can
      raise Hyrax::WorkflowAuthorizationException if doc.suppressed? && !current_ability.can?(:read, doc)
    end
    Hyrax::PresenterFactory.build_for(ids: ids,
                                      presenter_class: Hyrax::WorkShowPresenter,
                                      presenter_args: current_ability).first

  end
end
