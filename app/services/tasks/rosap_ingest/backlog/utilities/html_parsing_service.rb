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

    metadata['date_issued'] = safe_plain_text(doc.at_css('.bookHeaderListData p')) ||
                                   safe_content(doc.at_xpath('//meta[@name="citation_publication_date"]'))

    metadata['publisher'] = extract_multi_value_field(doc, 'Corporate Publisher', multiple: true)

    metadata['keywords'] = extract_keywords(doc)

    # Funding information is not consistently available; stub as empty array
    metadata['funder'] = []

    # WIP Log for metadata mapping (Remove later)
    wip_log_object = metadata.except('abstract')
    LogUtilsHelper.double_log("Parsed metadata: #{wip_log_object.inspect}", :debug, tag: 'HTMLParsingService')
    metadata
  end

  private

  def extract_keywords(doc)
    keywords_from_meta_tags = extract_keywords_from_meta_tags(doc)
    return keywords_from_meta_tags if keywords_from_meta_tags.any?
    # Fallback to details section
    extract_keywords_from_details_section(doc)
  end

  def extract_keywords_from_meta_tags(doc)
    tags = doc.xpath('//meta[@name="citation_keywords"]')

    tags.map { |tag| safe_content(tag) }.compact
  end

  def extract_keywords_from_details_section(doc)
    keyword_section = doc.css('#mesh-keywords')
    return [] if keyword_section.empty?

    keyword_links = keyword_section.css('a[id^="metadataLink-Subject/TRT Terms-"]')
    keyword_links.map { |link| link.text.strip }
  end

  def extract_multi_value_field(doc, label_text, multiple: false)
    section_matching_label = doc.css('.bookDetails-row').find do |row|
      safe_plain_text(row.at_css('.bookDetailsLabel')) == "#{label_text}:"
    end

    return multiple ? [] : nil unless section_matching_label

    if multiple
      # Extract all links as an array
      section_matching_label.css('.bookDetailsData a').map { |elem| safe_plain_text(elem) }
    else
      # Extract single value (prefer link text, fall back to any text)
      safe_plain_text(section_matching_label.at_css('.bookDetailsData')) ||
      safe_plain_text(section_matching_label.at_css('.bookDetailsData a'))
    end
  end

  def safe_plain_text(html_snippet)
    html_snippet&.text&.strip
  end

  def safe_content(meta_snippet)
    meta_snippet&.[]('content')
  end
end
