# Searches Solr in chunks for affiliations
module HycCrawlerService
  def self.person_fields
    [:advisors, :arrangers, :composers, :contributors, :creators, :project_directors,
     :researchers, :reviewers, :translators]
  end

  def self.person_classes
    [Article, Artwork, DataSet, Dissertation, General, HonorsThesis, Journal, MastersPaper]
  end

  def self.crawl_for_affiliations(&block)
    Rails.logger.info('Beginning to search for affiliations')
    person_classes.each do |klass|
      search_by_class(klass, &block)
    end
  end

  def self.search_by_class(klass)
    # search_in_batches returns RSolr::Response::PaginatedDocSet, each object in group is a hash of a solr response
    klass.search_in_batches('person_label_tesim:*') do |group|
      Rails.logger.info("Finding affiliations for group of #{klass} with ids: #{group.map { |solr_doc| solr_doc['id'] }}")
      group.map do |solr_doc|
        object = klass.find(solr_doc['id'])

        url = Rails.application.routes.url_helpers.url_for(object)
        # Sort so that we can test csv line more easily
        affiliations = all_person_affiliations(object).sort
        yield(solr_doc['id'], url, affiliations) unless affiliations.empty?
      end
    end
  end

  def self.csv_file_path
    csv_directory = Rails.root.join(ENV['DATA_STORAGE'], 'reports')
    FileUtils.mkdir_p(csv_directory)
    Rails.root.join(ENV['DATA_STORAGE'], 'reports', 'unmappable_affiliations.csv')
  end

  def self.csv_headers
    ['object_id', 'url', 'affiliations']
  end

  def self.create_csv_of_unmappable_affiliations
    CSV.open(csv_file_path, 'a+') do |csv|
      csv << csv_headers
      crawl_for_affiliations do |document_id, url, affiliations|
        unmappable_affiliations = unmappable_affiliations(affiliations)
        Rails.logger.debug("Saving object info to csv. url: #{url}") unless unmappable_affiliations.empty?
        csv << [document_id, url, unmappable_affiliations.join(' || ')] unless unmappable_affiliations.empty?
      end
    end
  end

  def self.person_affiliations_by_type(object, person_type)
    people_object = object.try(person_type)
    return unless people_object && !people_object.empty?

    affiliations = people_object.map { |person| person.attributes['affiliation'].to_a }
    # Remove nils and empty strings
    affiliations.flatten.reject { |e| e.to_s.empty? }
  end

  def self.unmappable_affiliations(affiliations)
    affiliations.map { |affil| DepartmentsService.label(affil) ? nil : affil }.compact
  end

  def self.all_person_affiliations(object)
    person_fields.map do |field|
      affiliations = person_affiliations_by_type(object, field)
      affiliations unless affiliations.nil? || affiliations.compact.empty?
    end.compact.flatten
  end
end
