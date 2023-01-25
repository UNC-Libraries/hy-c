# frozen_string_literal: true
# Helper methods for people object fields
module PersonHelper
  def self.people_fields
    @people_fields ||= [:advisors, :arrangers, :composers, :contributors, :creators,
                  :project_directors, :researchers, :reviewers, :translators]
  end

  def self.people_set
    @people_set ||= Set.new(people_fields)
  end

  # Returns true if the provided key is a person field.
  # Key can be either a string or a symbol
  def self.person_field?(key)
    people_set.include?(key.to_sym)
  end
end
