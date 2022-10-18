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
    text += add_title_text_for(work)
    text += add_publisher_text_for(work)
    # [hyc-override] Add DOI
    text = "#{text.strip} #{work.doi[0]}" if !work.doi.blank?

    text.html_safe
  end
  #rubocop:enable Rails/OutputSafety
end
