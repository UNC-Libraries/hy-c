class AffiliationRemediationService
  def initialize(id_csv_path)
    @id_csv_path = id_csv_path
  end

  def person_fields
    [:advisors, :arrangers, :composers, :contributors, :creators, :project_directors,
     :researchers, :reviewers, :translators]
  end

  def remediate_all_affiliations
    id_list.each do |id|
      object = object_by_id(id)
      next unless object

      update_affiliations(object)
      Rails.logger.info("Updated affiliations for object id: #{object.id}")
    end
  end

  def update_affiliations(object)
    person_fields.each do |person_field|
      next unless needs_updated_people?(object, person_field)

      update_affiliation_by_person_field(object, person_field)
    end
  end

  def update_affiliation_by_person_field(object, person_field)
    people_objects = object.try(person_field)

    new_attributes = []
    people_objects.each do |person|
      new_attributes << map_person_attributes(person.attributes)
    end
    object[person_field.to_s] = nil
    object.save!
    object.update("#{person_field}_attributes" => new_attributes)
    object.save!
  end

  def id_list
    @id_list ||= begin
      csv = CSV.parse(File.read(@id_csv_path), headers: true)
      csv.map { |row| row['object_id'] }
    end
  end

  def object_by_id(identifier)
    ActiveFedora::Base.find(identifier)
  rescue ActiveFedora::ObjectNotFoundError
    Rails.logger.warn("Object not found. Object identifier: #{identifier}")
    nil
  end

  def affiliation_map
    @affiliation_map ||= begin
      csv_path = 'spec/fixtures/files/umappable-affiliations-mapped-final.csv'
      csv = CSV.parse(File.read(csv_path), headers: true)
      csv.map { |row| { original_affiliation: row['original_affiliation'], new_affiliation: row['new_affiliation'] } }
    end
  end

  def map_to_new_affiliation(unmappable_affiliation)
    target_hash = affiliation_map.find { |affil| affil[:original_affiliation] == unmappable_affiliation }
    new_affiliation = target_hash.try(:[], :new_affiliation)
    return nil if new_affiliation.nil?

    if new_affiliation.include?('|')
      new_affiliation.split('|')
    else
      new_affiliation
    end
  end

  def map_person_attributes(attributes)
    # Do a json round trip to force any ActiveTriples into an array
    attributes_hash = JSON.parse(attributes.to_json)
    attributes_hash.delete('id')
    original_affiliation = attributes_hash['affiliation'].first
    new_affiliation = []
    if mappable_affiliation?(original_affiliation)
      new_affiliation << original_affiliation
    elsif map_to_new_affiliation(original_affiliation) == 'n/a'
      attributes_hash.delete('other_affiliation')
      attributes_hash['other_affiliation'] = [original_affiliation]
    elsif map_to_new_affiliation(original_affiliation)
      new_affiliation << map_to_new_affiliation(original_affiliation)
    end
    attributes_hash.delete('affiliation')
    attributes_hash['affiliation'] = new_affiliation.flatten
    attributes_hash
  end

  def mappable_affiliation?(affiliation)
    mapping = DepartmentsService.label(affiliation)
    mapping ? true : false
  end

  def needs_updated_people?(object, person_field)
    return false unless object.attributes.keys.member?(person_field.to_s)

    return false if object.try(person_field).blank?

    true
  end
end
