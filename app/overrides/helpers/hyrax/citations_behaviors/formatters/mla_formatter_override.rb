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
    title_info = setup_title_info(work)

    #[hyc-override] Use separate formatting structure for journal citations,
    if journal_citation?(work)
      text += format_journal_title(title_info)

      journal_info = format_journal_info(work)
      text += " #{journal_info}" if journal_info.present?
    else
      text += format_title(title_info)

      pub_info = clean_end_punctuation(setup_pub_info(work, true))
      text += (pub_info + '.') if pub_info.present?
    end

    # [hyc-override] Add DOI
    doi = setup_doi(work)
    text = "#{text.strip} #{doi}" if doi.present?

    text.html_safe
  end

  def format_journal_title(title_info)
    return '' if title_info.blank?

    title = mla_citation_title(clean_end_punctuation(title_info))
    "<span class=\"citation-title\">\"#{title}.\"</span>"
  end

  def format_journal_info(work)
    metadata = setup_journal_metadata(work)

    parts = [
      metadata[:journal_title].present? ? "<i class=\"citation-journal-title\">#{metadata[:journal_title]}</i>" : nil,
      metadata[:journal_volume].present? ? "vol. #{metadata[:journal_volume]}" : nil,
      metadata[:journal_issue].present? ? "no. #{metadata[:journal_issue]}" : nil,
      metadata[:pub_date],
      setup_mla_page_range(work)
    ].compact_blank

    append_period(parts.join(', ').presence)
  end
  #rubocop:enable Rails/OutputSafety
end
