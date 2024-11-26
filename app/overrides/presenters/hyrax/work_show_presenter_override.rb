# frozen_string_literal: true
# [hyc-override] Overriding helper in order to add doi to citation
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/presenters/hyrax/work_show_presenter.rb
Hyrax::WorkShowPresenter.class_eval do
  # delegating just :doi seems to exclude the other fields, so pull all fields in from original file
  delegate :title, :date_created, :date_issued, :description, :doi, :creator, :place_of_publication,
           :creator_display, :contributor, :subject, :publisher, :language, :embargo_release_date,
           :lease_expiration_date, :license, :source, :rights_statement, :thumbnail_id, :representative_id,
           :rendering_ids, :member_of_collection_ids, :member_ids, :alternative_title, :bibliographic_citation, to: :solr_document

  # [hyc-override] Add default scholarly? method
  # Indicates if the work is considered scholarly according to google scholar
  # This method is not defined in hyrax, but it is referenced by GoogleScholarPresenter
  def scholarly?
    false
  end

  # def fetch_primary_fileset_id
  #   Rails.logger.info 'Hyrax::WorkShowPresenter#fetch_primary_fileset_id'
  #   res = representative_id.blank? ? member_ids.first : representative_id
  #   Rails.logger.info "res: #{res}"
  #   res
  # end


    # @return FileSetPresenter presenter for the representative FileSets
  # def representative_presenter
  #   # Rails.logger.info "fetch primary check: #{fetch_primary_fileset_id.present?}"
  #   # Rails.logger.info "Hyrax::WorkShowPresenter#representative_presenter"
  #   # Rails.logger.info "representative_id: #{representative_id}"
  #   # Rails.logger.info "member of collection ids: #{member_of_collection_ids.inspect}"
  #   # Rails.logger.info "member ids: #{member_ids.inspect}"
  #   condition = representative_id.blank? && member_ids.blank?
  #   Rails.logger.info "condition: #{condition}"
  #   return nil if fetch_primary_fileset_id.blank?
  #   @representative_presenter ||=
  #     begin
  #       result = member_presenters([fetch_primary_fileset_id]).first
  #       # Rails.logger.info "representative_presenter-result: #{result.inspect}"
  #       return nil if result.try(:id) == id
  #       # Rails.logger.info "representative_presenter-result-id: #{result.try(:id)}"
  #       Rails.logger.info "representative_presenter-OR: #{result.try(:representative_presenter) || result}"
  #       result.try(:representative_presenter) || result
  #     rescue Hyrax::ObjectNotFoundError
  #       # Hyrax.logger.warn "Unable to find representative_id #{temp} for work #{id}"
  #       # Rails.logger.warn "Unable to find representative_id #{temp} for work #{id}"
  #       # Rails.logger.info "Unable to find representative_id #{temp} for work #{id}"
  #       return nil
  #     end
  # end
end
