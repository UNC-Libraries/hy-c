# frozen_string_literal: true
# [hyc-override] Overriding helper in order to add doi to citation
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/presenters/hyrax/work_show_presenter.rb
Hyrax::WorkShowPresenter.class_eval do
  # delegating just :doi seems to exclude the other fields, so pull all fields in from original file
  delegate :title, :date_created, :date_issued, :description, :doi, :creator, :place_of_publication,
           :creator_display, :contributor, :subject, :publisher, :language, :embargo_release_date,
           :lease_expiration_date, :license, :source, :rights_statement, :thumbnail_id, :representative_id,
           :rendering_ids, :member_of_collection_ids, :member_ids, :alternative_title, to: :solr_document

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
    primary_fileset_id = fetch_primary_fileset_id
    return nil if primary_fileset_id.blank?
    @representative_presenter ||=
      begin
        result = member_presenters([primary_fileset_id]).first
        return nil if result.try(:id) == id
        result.try(:representative_presenter) || result
      rescue Hyrax::ObjectNotFoundError
        Hyrax.logger.warn "Unable to find representative_id #{primary_fileset_id} for work #{id}"
        return nil
      end
  end
end
