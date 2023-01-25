# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/helpers/hyrax/citations_behaviors/formatters/mla_formatter.rb
Hyrax::CitationsBehaviors::Formatters::MlaFormatter.class_eval do
  # [hyc-override] Add helper, which is used by some of the behaviors included at a higher level
  include HycHelper

  # rubocop:disable Rails/OutputSafety
  def format(work)
    text = ''

    # setup formatted author list
    authors = author_list(work).reject(&:blank?)
    text += "<span class=\"citation-author\">#{format_authors(authors)}</span>"
    # setup title
    title_info = setup_title_info(work)
    text += format_title(title_info)

    # Publication
    pub_info = clean_end_punctuation(setup_pub_info(work, true))

    text += "#{pub_info}. " if pub_info.present?
    # [hyc-override] Add DOI
    text = "#{text.strip} #{work.doi[0]}" if !work.doi.blank?
    text.html_safe
  end
  #rubocop:enable Rails/OutputSafety
end
