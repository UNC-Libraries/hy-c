# [hyc-override] Overriding work form in hyrax gem to allow default fields to be singular
class SingleValueForm < Hyrax::Forms::WorkForm
  
  # Field which will not be rendered to the work form
  class_attribute :admin_only_terms
  self.admin_only_terms = Array.new
  # Map of fields to default values
  class_attribute :default_term_values
  self.default_term_values = Hash.new

  self.terms += [:language_label, :license_label, :rights_statement_label]

  def initialize(model, current_ability, controller)
    initialize_default_term_values(model)
    
    super(model, current_ability, controller)
  end

  def self.multiple?(field)
    if single_value_fields.include? field.to_sym
      false
    else
      super
    end
  end

  # cast single value fields back to multivalued so they will actually deposit
  def self.model_attributes(form_params)
    attrs = super

    single_value_fields.each do |field|
      if attrs[field]
        if attrs[field].blank?
          attrs[field] = []
        else
          attrs[field] = Array(attrs[field])
        end
      end
    end
    
    # For new works, add default values in if the field key is not present, as this indicates
    # that the field was not present in the form
    is_new_model = !form_params.has_key?(:permissions_attributes)
    if is_new_model
      default_term_values.each do |field, values|
        if !attrs.key?(field)
          values = default_term_values[field]
          
          if multiple? field.to_sym
            if attrs[field].blank?
              attrs[field] = values
            end
          else
            if attrs[field].blank?
              attrs[field] = values.first
            end
          end
        end
      end
    end

    @person_label = []
    @orcid_label = []
    @affiliation_label = []
    @other_affiliation_label = []

    if attrs.key?(:advisors_attributes) && !attrs[:advisors_attributes].blank?
      attrs[:advisors_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:advisor_display] = attrs[:advisors_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:arrangers_attributes) && !attrs[:arrangers_attributes].blank?
      attrs[:arrangers_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:arranger_display] = attrs[:arrangers_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:composers_attributes) && !attrs[:composers_attributes].blank?
      attrs[:composers_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:composer_display] = attrs[:composers_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:contributors_attributes) && !attrs[:contributors_attributes].blank?
      attrs[:contributors_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:contributor_display] = attrs[:contributors_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:creators_attributes) && !attrs[:creators_attributes].blank?
      attrs[:creators_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:creator_display] = attrs[:creators_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:project_directors_attributes) && !attrs[:project_directors_attributes].blank?
      attrs[:project_directors_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:project_director_display] = attrs[:project_directors_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:researchers_attributes) && !attrs[:researchers_attributes].blank?
      attrs[:researchers_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:researcher_display] = attrs[:researchers_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:reviewers_attributes) && !attrs[:reviewers_attributes].blank?
      attrs[:reviewers_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:reviewer_display] = attrs[:reviewers_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:translators_attributes) && !attrs[:translators_attributes].blank?
      attrs[:translators_attributes].map{ |k, v| person_label_fields(v) }
      attrs[:translator_display] = attrs[:translators_attributes].map{ |k, v| build_person_display(v) }
    end

    if attrs.key?(:language) && !attrs[:language].blank?
      Array(attrs[:language]).each do |language|
        attrs[:language_label] << LanguagesService.label(language)
      end
    end

    if attrs.key?(:license) && !attrs[:license].blank?
      Array(attrs[:license]).each do |license|
        attrs[:license_label] << CdrLicenseService.label(license)
      end
    end

    if attrs.key?(:rights_statement) && !attrs[:rights_statement].blank?
      attrs[:rights_statement_label] = CdrRightsStatementsService.label(attrs[:rights_statement])
    end

    attrs[:person_label] = @person_label.flatten.uniq if !@person_label.blank?
    attrs[:orcid_label] = @orcid_label.flatten.uniq if !@orcid_label.blank?
    attrs[:affiliation_label] = @affiliation_label.flatten.uniq if !@affiliation_label.blank?
    attrs[:other_affiliation_label] = @other_affiliation_label.flatten.uniq if !@other_affiliation_label.blank?

    attrs
  end



  private
    def initialize_default_term_values(model)
      # Do not set default values for existing works
      if model.id != nil
        return
      end

      default_term_values.each do |field, values|
        Rails.logger.debug "Init field #{field} with default values #{values.inspect} or retain existing #{model[field].inspect}"

        if model[field].blank?
          if single_value_fields.include? field.to_sym
            model[field].set(values.first)
          elsif !model[field].kind_of?(Array)
            model[field] = values
          else
            model[field].set(values)
          end
        end
      end
    end

    # split affiliations out
    def self.split_affiliations(affiliations)
      affiliations_list = []

      Array(affiliations).reject { |a| a.blank? }.each do |aff|
        Array(DepartmentsService.label(aff)).join(';').split(';').each do |value|
          affiliations_list.push(value.squish!)
        end
      end

      affiliations_list.uniq
    end

    def self.build_person_display(person_attrs)
      display_text = []
      display_text << person_attrs['name'] if !person_attrs['name'].blank?
      display_text << "ORCID: #{person_attrs['orcid']}" if !person_attrs['orcid'].blank?
      display_text << "Affiliation: #{split_affiliations(person_attrs['affiliation']).join(', ')}" if !person_attrs['affiliation'].blank?
      display_text << "Other Affiliation: #{person_attrs['other_affiliation']}" if !person_attrs['other_affiliation'].blank?
      display_text.join(';')
    end

    def self.person_label_fields(person_attrs)
      if !person_attrs['name'].blank?
        @person_label.push(person_attrs['name'])
        @orcid_label.push(person_attrs['orcid']) if !person_attrs['orcid'].blank?
        @affiliation_label.push(split_affiliations(person_attrs['affiliation'])) if !person_attrs['affiliation'].blank?
        @other_affiliation_label.push(person_attrs['other_affiliation']) if !person_attrs['other_affiliation'].blank?
      end
    end
end