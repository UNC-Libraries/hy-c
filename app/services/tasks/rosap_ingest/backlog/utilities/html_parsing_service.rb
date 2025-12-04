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

    metadata['publisher'] = extract_multi_value_field(doc, 'Corporate Publisher', multiple: false)

    metadata['keywords'] = extract_keywords(doc)

    # Funding information is not consistently available; stub as empty array
    metadata['funder'] = []

    metadata['authors'] = extract_authors(doc)

    metadata
  end

  def extract_keywords(doc)
    keywords_from_meta_tags = extract_keywords_from_meta_tags(doc)
    return keywords_from_meta_tags if keywords_from_meta_tags.any?
    # Fallback to details section
    extract_keywords_from_details_section(doc)
  end

  def extract_authors(doc)
    authors_from_details_section = extract_authors_from_details_section(doc)
    return authors_from_details_section if authors_from_details_section.any?
    # Fallback to meta tags
    extract_authors_from_meta_tags(doc)
  end

  private

  def extract_authors_from_details_section(doc)
    author_section = doc.at_css('#moretextPAmods\\.sm_creator')
    return [] unless author_section

    author_links = author_section.css('a[id^="metadataLink-Creators-"]')

    author_links.map.with_index do |link, index|
      author_name = safe_plain_text(link)
      orcid = extract_orcid_for_author(link)

      {
        'name' => author_name,
        'orcid' => orcid,
        'index' => index.to_s
      }
    end
  end

  def extract_authors_from_meta_tags(doc)
    tags = doc.xpath('//meta[@name="citation_author"]')

    tags.map.with_index do |tag, index|
      author_name = safe_content(tag)
      next unless author_name

      {
        'name' => author_name,
        'orcid' => '',
        'index' => index.to_s
      }
    end.compact
  end

  def extract_orcid_for_author(author_link)
    orcid_link = author_link.next_element
    return '' unless orcid_link&.[]('href')&.include?('orcid.org')

    orcid_link['href'].split('/').last
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
