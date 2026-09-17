# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/presenters/hyrax/file_set_presenter.rb
Hyrax::FileSetPresenter.class_eval do
  include EmbargoHistoryPresenter

  # Get parent embargo history, as the file set doesn't have this field.
  def embargo_history
    history = super
    return history unless history.empty?

    fetch_parent_presenter&.solr_document&.fetch('embargo_history_ssim', []) || []
  end

  def fetch_parent_presenter
    ids = Hyrax::SolrService.query("{!field f=member_ids_ssim}#{id}", fl: Hyrax.config.id_field, rows: 1)
                            .map { |x| x.fetch(Hyrax.config.id_field) }
    if ids.empty?
      Hyrax.logger.warn("Couldn't find a parent work for FileSet: #{id}.")
    else
      parent_presenter = Hyrax::PresenterFactory.build_for(ids: ids,
                                                            presenter_class: Hyrax::WorkShowPresenter,
                                                            presenter_args: current_ability).first
      parent_document = parent_presenter.solr_document
      unless current_ability.can?(:edit, parent_document)
        # [hyc-override] throw exception when suppressed if user CANNOT read the doc, rather than if they can
        raise Hyrax::WorkflowAuthorizationException if parent_document.suppressed? && !current_ability.can?(:read, parent_document)
      end
      return parent_presenter
    end
    Hyrax::PresenterFactory.build_for(ids: ids,
                                      presenter_class: Hyrax::WorkShowPresenter,
                                      presenter_args: current_ability).first
  end
end
