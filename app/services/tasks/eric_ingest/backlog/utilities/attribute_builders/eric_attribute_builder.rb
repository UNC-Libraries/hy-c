module Tasks::EricIngest::Backlog::Utilities::AttributeBuilders
  class EricAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder

    def get_date_issued
      pub_year = metadata['PublicationYear'] 
      DateTime.new(pub_year.to_i) if pub_year.present?
    end

    private

    def generate_authors
      metadata['Author'].map.with_index do |full_name, i|
        {
          'name' => full_name,
          'index' => i.to_s
        }
      end
    end

    def apply_additional_basic_attributes(article)
        article.title = [metadata['title']]
        article.abstract = [metadata['description']] if metadata['abstract'].present?
        article.date_issued = get_date_issued.strftime('%Y-%m-%d')
        article.keyword = metadata['subject'] if metadata['subject'].present?
        article.publisher = [metadata['publisher']] if metadata['publisher'].present?
    end

    def set_identifiers(article)
        identifiers = []
        if metadata['eric_id'].present?
            identifiers << "ERIC: #{metadata['eric_id']}"
        end

         if metadata['issn'].present?
            metadata['issn'].each do |issn|
            # remove the "ISSN-" prefix if present, and strip whitespace
            article.issn = [issn.sub(/^ISSN[-:\s]*/i, '').strip]
            end
        end
        article.identifier = identifiers
    end
end