# frozen_string_literal: true
# [hyc-override] Overriding helper in order to use date_issued, if present, for publication date
# [hyc-override] Add check that presenter has place of publication method
# https://github.com/samvera/hyrax/blob/v2.9.6/app/helpers/hyrax/citations_behaviors/publication_behavior.rb
Hyrax::CitationsBehaviors::PublicationBehavior.module_eval do
  def setup_pub_date(work)
    first_date = ''
    if work.respond_to?(:date_issued)
      file_date = work.date_issued
      if file_date.is_a?(String) || !file_date.respond_to?(:first)
        first_date = file_date
      else
        first_date = file_date.first
      end
    end

    date_value = nil
    if first_date&.present?
      first_date = CGI.escapeHTML(first_date)
      date_value = /\d{4}/.match(first_date)
      return nil if date_value.blank?
    end
    clean_end_punctuation(date_value[0]) if date_value
  end

  def setup_pub_place(work_presenter)
    work_presenter.place_of_publication&.first if work_presenter.respond_to?(:place_of_publication)
  end

  def setup_pub_info(work, include_date = false)
    pub_info = ''
    if (place = setup_pub_place(work))
      pub_info += CGI.escapeHTML(place)
    end
    if (publisher = setup_pub_publisher(work))
      pub_info += ': ' unless place.to_s == ''
      pub_info += CGI.escapeHTML(publisher)
    end

    pub_date = include_date ? setup_pub_date(work) : nil
    # [hyc-override] Skip adding leading comma when no content
    pub_info += ', ' unless pub_info.blank?
    pub_info += pub_date unless pub_date.nil?

    # [hyc-override] Remove any trailing commas
    pub_info.strip.chomp(',').presence
  end
end
