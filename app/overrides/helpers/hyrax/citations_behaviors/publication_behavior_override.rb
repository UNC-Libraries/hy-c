# frozen_string_literal: true
# [hyc-override] Overriding helper in order to use date_issued, if present, for publication date
# https://github.com/samvera/hyrax/blob/v2.9.6/app/helpers/hyrax/citations_behaviors/publication_behavior.rb
Hyrax::CitationsBehaviors::PublicationBehavior.class_eval do
  def setup_pub_date(work)
    first_date = ''
    if work.respond_to?(:date_issued)
      file_date = work.date_issued
      first_date = file_date.is_a?(String) ? file_date : file_date.first
    end

    date_value = nil
    if first_date&.present?
      first_date = CGI.escapeHTML(first_date)
      date_value = /\d{4}/.match(first_date)
      return nil if date_value.blank?
    end
    clean_end_punctuation(date_value[0]) if date_value
  end
end
