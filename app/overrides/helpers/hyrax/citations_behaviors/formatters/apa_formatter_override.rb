# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/helpers/hyrax/citations_behaviors/formatters/apa_formatter.rb
Hyrax::CitationsBehaviors::Formatters::ApaFormatter.class_eval do
  # [hyc-override] Add helper, which is used by some of the behaviors included at a higher level
  include HycHelper

  # rubocop:disable Rails/OutputSafety
  def format(work)
    text = ''
    text += authors_text_for(work)
    text += pub_date_text_for(work)

    # [hyc-override] Add separate handling for journal citations, which is not handled in Hyrax proper
    if journal_citation?(work)
      text += format_journal_title(setup_title_info(work))

      journal_info = format_journal_info(work)
      text += " #{journal_info}" if journal_info.present?
    else
      text += add_title_text_for(work)
      text += add_publisher_text_for(work)
    end

    # [hyc-override] Add DOI
    doi = setup_doi(work)
    text = "#{text.strip} #{doi}" if doi.present?

    text.html_safe
  end

  def format_journal_title(title_info)
    return '' if title_info.blank?

    title = clean_end_punctuation(title_info)
    "<span class=\"citation-title\">#{title}.</span>"
  end

  def format_journal_info(work)
    metadata = setup_journal_metadata(work)
    journal_parts = [metadata[:journal_title], metadata[:journal_volume]].compact_blank

    journal =
      if journal_parts.present?
        "<i class=\"citation-journal-title\">#{journal_parts.join(', ')}</i>"
      end

    journal_issue = metadata[:journal_issue].present? ? "(#{metadata[:journal_issue]})" : nil
    journal = [journal, journal_issue].compact_blank.join

    append_period([journal, metadata[:page_range]].compact_blank.join(', ').presence)
  end
  #rubocop:enable Rails/OutputSafety
end
