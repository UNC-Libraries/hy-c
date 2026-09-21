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

    pub_date = setup_pub_date(work)
    text += " #{whitewash(pub_date)}." if pub_date.present? && !journal_citation?(work)

    if journal_citation?(work)
      text += format_journal_title(setup_title_info(work))

      journal_info = format_journal_info(work)
      text += " #{journal_info}" if journal_info.present?
    else
      text += format_title(work.to_s)
      pub_info = setup_pub_info(work, false)
      text += " #{whitewash(pub_info)}." if pub_info.present?
    end

    doi = setup_doi(work)
    text = "#{text.strip} #{doi}" if doi.present?

    text.html_safe
  end

  def format_journal_title(title_info)
    return '' if title_info.blank?

    title = chicago_citation_title(clean_end_punctuation(title_info))
    " <span class=\"citation-title\">\"#{title}.\"</span>"
  end

  def format_journal_info(work)
    metadata = setup_journal_metadata(work)

    formatted_title =
      if metadata[:journal_title].present?
        "<i class=\"citation-journal-title\">#{metadata[:journal_title]}</i>"
      end

    journal = [formatted_title, metadata[:journal_volume]].compact_blank.join(' ').presence

    if metadata[:journal_issue].present?
      issue = "no. #{metadata[:journal_issue]}"
      journal = [journal, issue].compact_blank.join(', ').presence
    end

    if metadata[:pub_date].present?
      date = "(#{metadata[:pub_date]})"
      journal = [journal, date].compact_blank.join(' ').presence
    end

    journal = [journal, metadata[:page_range]].compact_blank.join(': ').presence

    append_period(journal)
  end
  #rubocop:enable Rails/OutputSafety
end
