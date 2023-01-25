# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/presenters/hyrax/file_set_presenter.rb
Hyrax::FileSetPresenter.class_eval do
  def fetch_parent_presenter
    ids = Hyrax::SolrService.query("{!field f=member_ids_ssim}#{id}", fl: Hyrax.config.id_field)
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
