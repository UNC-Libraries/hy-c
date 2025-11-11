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