# For information on the JATS metadata standard, see https://jats.nlm.nih.gov/
# Currently used for Sage ingest
class JatsIngestWork
  include ActiveModel
  attr_reader :xml_path

  def initialize(xml_path:)
    @xml_path = xml_path
  end

  def jats_xml
    @jats_xml ||= File.read(xml_path)
  end

  def document
    @document ||= Nokogiri::XML(jats_xml)
  end

  def article_metadata
    @article_metadata ||= document.xpath('.//article-meta')
  end

  def creators_metadata
    @creators_metadata ||= document.xpath('.//contrib-group')
  end

  def journal_metadata
    @journal_metadata ||= document.xpath('.//journal-meta')
  end

  def permissions
    @permissions ||= article_metadata.xpath('.//permissions')
  end

  def abstract
    article_metadata.xpath('.//abstract').map(&:inner_text)
  end

  def copyright_date
    permissions.at('copyright-year').inner_text
  end

  def creators
    @creators ||= creators_metadata.xpath('.//contrib').map.with_index do |contributor, index|
      [index, contributor_to_hash(contributor, index)]
    end.to_h
  end

  # TODO: Map affiliation to UNC controlled vocabulary
  def contributor_to_hash(contributor, index)
    affiliation_ids = affiliation_ids(contributor)
    first_affiliation = affiliation_map[affiliation_ids.first]
    {
      'name' => "#{surname(contributor)}, #{given_names(contributor)}",
      'orcid' => orcid(contributor),
      'affiliation' => '',
      # 'affiliation' => some_method, # Do not store affiliation until we can map it to the controlled vocabulary
      'other_affiliation' => first_affiliation,
      'index' => (index + 1).to_s
    }
  end

  def affiliation_map
    @affiliation_map ||= document.xpath('//aff').map do |affil|
      [affil.attributes['id'].value, affiliation_to_s(affil)]
    end.to_h
  end

  def affiliation_ids(elem)
    references = elem.xpath('xref')
    references.map do |ref|
      reference_type = ref['ref-type']
      next unless reference_type == 'aff'

      ref['rid']
    end.compact
  end

  def affiliation_to_s(affil_elem)
    affil_elem.children.map do |child|
      # Don't include newlines or the order label
      next if child.inner_text == "\n" || child.name == 'label'

      # Only include the institution name proper from the institution-wrap, don't include the institution-id
      if child.xpath('.//institution').present?
        child.xpath('.//institution').inner_text
      else
        child.inner_text
      end
    end.join
  end

  def date_of_publication
    if publication_day && publication_month && publication_year
      "#{publication_year}-#{publication_month}-#{publication_day}"
    elsif publication_month && publication_year
      "#{publication_year}-#{publication_month}"
    else
      publication_year
    end
  end

  def funder
    article_metadata.xpath('.//funding-source/institution-wrap/institution').map(&:inner_text)
  end

  # The Sage-assigned DOI
  def identifier
    doi = article_metadata.xpath('.//article-id[@pub-id-type="doi"]').inner_text
    return [doi] if doi.start_with?('http')

    ["https://doi.org/#{doi}"]
  end

  def issn
    journal_metadata.xpath('.//issn').map(&:inner_text)
  end

  def journal_issue
    article_metadata.at('issue')&.inner_text
  end

  def journal_title
    journal_metadata.xpath('.//journal-title-group/journal-title').inner_text
  end

  def journal_volume
    article_metadata.at('volume')&.inner_text
  end

  def keyword
    keyword_list = article_metadata.at('kwd-group')
    return [] if keyword_list.nil?

    keyword_list.xpath('//kwd').map do |elem|
      if elem.at('italic')
        elem.at('italic').inner_text
      else
        elem.inner_text
      end
    end
  end

  def license
    permissions.xpath('.//license/@xlink:href').map do |elem|
      controlled_vocab_hash = CdrLicenseService.authority.find(elem&.inner_text)
      Rails.logger.warn("Could not match license uri: #{elem&.inner_text} to a license in the controlled vocabulary. Work with DOI #{identifier&.first} may not include the required license.") if controlled_vocab_hash.empty?
      controlled_vocab_hash[:id]
    end.compact
  end

  def license_label
    license.map do |lic|
      CdrLicenseService.label(lic)
    end
  end

  def page_end
    article_metadata.at('lpage')&.inner_text
  end

  def page_start
    article_metadata.at('fpage')&.inner_text
  end

  def publisher
    journal_metadata.xpath('.//publisher/publisher-name').map(&:inner_text)
  end

  def rights_holder
    permissions.xpath('.//copyright-holder').map(&:inner_text)
  end

  def title
    article_metadata.xpath('.//title-group/article-title').map(&:inner_text)
  end

  private

  def publication_year
    year = publication_date_node_set.at('year')&.inner_text&.to_i
    format('%04d', year) if year
  end

  def publication_month
    month = publication_date_node_set.at('month')&.inner_text&.to_i
    format('%02d', month) if month
  end

  def publication_day
    day = publication_date_node_set.at('day')&.inner_text&.to_i
    format('%02d', day) if day
  end

  def publication_date_node_set
    if physical_publication_date.present?
      physical_publication_date
    elsif electronic_and_physical_publication_date.present?
      electronic_and_physical_publication_date
    elsif electronic_publication_date.present?
      electronic_publication_date
    end
  end

  def electronic_publication_date
    article_metadata.xpath('.//pub-date[@pub-type="epub"]')
  end

  def electronic_and_physical_publication_date
    article_metadata.xpath('.//pub-date[@pub-type="epub-ppub"]')
  end

  def physical_publication_date
    article_metadata.xpath('.//pub-date[@pub-type="ppub"]')
  end

  def surname(contributor)
    contributor.xpath('name/surname').inner_text
  end

  def given_names(contributor)
    contributor.xpath('name/given-names').inner_text
  end

  def orcid(contributor)
    contributor.xpath('contrib-id').inner_text
  end
end
