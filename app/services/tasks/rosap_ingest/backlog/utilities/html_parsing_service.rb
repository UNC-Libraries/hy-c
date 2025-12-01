# frozen_string_literal: true
module Tasks::RosapIngest::Backlog::Utilities::HTMLParsingService
  extend self
  def parse_metadata_from_html(html_content)
    doc = Nokogiri::HTML(html_content)
    metadata = {}

    metadata['title'] = safe_plain_text(doc.at_css('h1#mainTitle')) ||
                        safe_content(doc.at_xpath('//meta[@name="citation_title"]'))

    metadata['abstract'] = safe_plain_text(doc.at_css('#collapseDetails')) ||
                           safe_content(doc.at_xpath('//meta[@name="citation_abstract"]'))

    metadata['publication_date'] = safe_plain_text(doc.at_css('.bookHeaderListData p')) ||
                                   safe_content(doc.at_xpath('//meta[@name="citation_publication_date"]'))

    # WIP Log for metadata mapping (Remove later)
    wip_log_object = metadata.slice('title', 'publication_date')
    LogUtilsHelper.double_log("Parsed metadata: #{wip_log_object.inspect}", :debug, tag: 'HTMLParsingService')
    metadata
  end

  private

  def safe_plain_text(html_snippet)
    html_snippet&.text&.strip
  end

  def safe_content(meta_snippet)
    meta_snippet&.[]('content')
  end
end
