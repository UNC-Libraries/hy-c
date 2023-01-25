# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/presenters/hyrax/google_scholar_presenter.rb
Hyrax::GoogleScholarPresenter.class_eval do
  # [hyc-override] include helper for sorting creators
  include HycHelper

  # [hyc-override] use person objects for authors
  def authors
    return [] if object.creator_display.blank?

    sort_people_by_index(object.creator_display)
        .map { |creator| creator.split('||').second }
  end

  # [hyc-override] use date issued instead of created
  def publication_date
    Array(object.try(:date_issued)).first || ''
  end

  # [hyc-override] Additional journal fields not currently populated by hyrax
  ##
  # @return [String] a string representing the journal title
  def journal_title
    Array(object.try(:journal_title)).first || ''
  end

  ##
  # @return [String] a string representing the journal volume
  def volume
    Array(object.try(:journal_volume)).first || ''
  end

  ##
  # @return [String] a string representing the journal issue
  def issue
    Array(object.try(:journal_issue)).first || ''
  end

  ##
  # @return [String] a string representing the first page
  def firstpage
    Array(object.try(:page_start)).first || ''
  end

  ##
  # @return [String] a string representing the last page
  def lastpage
    Array(object.try(:page_end)).first || ''
  end
end
