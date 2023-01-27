# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/helpers/hyrax/citations_behaviors/formatters/chicago_formatter.rb
Hyrax::CitationsBehaviors::Formatters::ChicagoFormatter.class_eval do
  # [hyc-override] Add helper, which is used by some of the behaviors included at a higher level
  include HycHelper

  # rubocop:disable Rails/OutputSafety
  def format(work)
    text = ''

    # setup formatted author list
    # [hyc-override] remove blank authors, otherwise it will generate an error
    authors_list = all_authors(work).reject(&:blank?)
    text += format_authors(authors_list)
    text = "<span class=\"citation-author\">#{text}</span>" if text.present?
    # Get Pub Date
    pub_date = setup_pub_date(work)
    text += " #{whitewash(pub_date)}." unless pub_date.nil?

    text += format_title(work.to_s)
    pub_info = setup_pub_info(work, false)
    text += " #{whitewash(pub_info)}." if pub_info.present?
    # [hyc-override] Add DOI
    text = "#{text.strip} #{work.doi[0]}" if !work.doi.blank?
    text.html_safe
  end
  #rubocop:enable Rails/OutputSafety
end
