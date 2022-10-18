Hyrax::CitationsBehaviors::Formatters::ApaFormatter.class_eval do
  include HycHelper

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
end