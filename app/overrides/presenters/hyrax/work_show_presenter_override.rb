# frozen_string_literal: true
# [hyc-override] Overriding helper in order to add doi to citation
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/presenters/hyrax/work_show_presenter.rb
Hyrax::WorkShowPresenter.class_eval do
  # delegating just :doi seems to exclude the other fields, so pull all fields in from original file
  delegate :title, :date_created, :date_issued, :description, :doi, :creator, :place_of_publication,
           :creator_display, :contributor, :subject, :publisher, :language, :embargo_release_date,
           :lease_expiration_date, :license, :source, :rights_statement, :thumbnail_id, :representative_id,
           :rendering_ids, :member_of_collection_ids, :alternative_title, :bibliographic_citation, to: :solr_document

  # [hyc-override] Add default scholarly? method
  # Indicates if the work is considered scholarly according to google scholar
  # This method is not defined in hyrax, but it is referenced by GoogleScholarPresenter
  def scholarly?
    false
  end
end
