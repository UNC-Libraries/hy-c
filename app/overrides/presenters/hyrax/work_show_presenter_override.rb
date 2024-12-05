# frozen_string_literal: true
# [hyc-override] Overriding helper in order to add doi to citation
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/presenters/hyrax/work_show_presenter.rb
Hyrax::WorkShowPresenter.class_eval do
  include Hyrax::SharedDelegates

  # [hyc-override] Add default scholarly? method
  # Indicates if the work is considered scholarly according to google scholar
  # This method is not defined in hyrax, but it is referenced by GoogleScholarPresenter
  def scholarly?
    false
  end

  def fetch_primary_fileset_id
    res = representative_id.blank? ? member_ids.first : representative_id
    res
  end

  # [hyc-override] Use a work's first related fileset_id instead of the representative_id if it's nil
  # @return FileSetPresenter presenter for the representative FileSets
  def representative_presenter
    @representative_presenter ||=
      begin
        primary_fileset_id = fetch_primary_fileset_id
        return nil if primary_fileset_id.blank?
        result = member_presenters([primary_fileset_id]).first
        return nil if result.try(:id) == id
        result.try(:representative_presenter) || result
      rescue Hyrax::ObjectNotFoundError
        Hyrax.logger.warn "Unable to find representative_id #{primary_fileset_id} for work #{id}"
        return nil
      end
  end
end
