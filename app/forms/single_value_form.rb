# [hyc-override] Overriding work form in hyrax gem to allow default fields to be singular
class SingleValueForm < Hyrax::Forms::WorkForm
  
  # Field which will not be rendered to the work form
  class_attribute :admin_only_terms
  self.admin_only_terms = Array.new
  # Map of fields to default values
  class_attribute :default_term_values
  self.default_term_values = Hash.new
  # Fields in person class
  class_attribute :person_fields
  self.person_fields = [:advisor, :arranger, :composer, :contributor, :creator, :project_director, :researcher,
                        :reviewer, :translator]

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
    @creator_label = []
    @advisor_label = []
    @orcid_label = []
    @affiliation_label = []
    @other_affiliation_label = []

    if attrs.key?(:advisors_attributes) && !attrs[:advisors_attributes].blank?
      person_label_fields(attrs[:advisors_attributes])
      facet_field(attrs[:advisors_attributes], 'advisor')
      attrs[:advisor_display] = build_person_display(attrs[:advisors_attributes])
      attrs[:advisor_label] = @advisor_label
    end

    if attrs.key?(:arrangers_attributes) && !attrs[:arrangers_attributes].blank?
      person_label_fields(attrs[:arrangers_attributes])
      attrs[:arranger_display] = build_person_display(attrs[:arrangers_attributes])
    end

    if attrs.key?(:composers_attributes) && !attrs[:composers_attributes].blank?
      person_label_fields(attrs[:composers_attributes])
      attrs[:composer_display] = build_person_display(attrs[:composers_attributes])
    end

    if attrs.key?(:contributors_attributes) && !attrs[:contributors_attributes].blank?
      person_label_fields(attrs[:contributors_attributes])
      attrs[:contributor_display] = build_person_display(attrs[:contributors_attributes])
    end

    if attrs.key?(:creators_attributes) && !attrs[:creators_attributes].blank?
      person_label_fields(attrs[:creators_attributes])
      facet_field(attrs[:creators_attributes], 'creator')
      attrs[:creator_display] = build_person_display(attrs[:creators_attributes])
      attrs[:creator_label] = @creator_label
    end

    if attrs.key?(:project_directors_attributes) && !attrs[:project_directors_attributes].blank?
      person_label_fields(attrs[:project_directors_attributes])
      attrs[:project_director_display] = build_person_display(attrs[:project_directors_attributes])
    end

    if attrs.key?(:researchers_attributes) && !attrs[:researchers_attributes].blank?
      person_label_fields(attrs[:researchers_attributes])
      attrs[:researcher_display] = build_person_display(attrs[:researchers_attributes])
    end

    if attrs.key?(:reviewers_attributes) && !attrs[:reviewers_attributes].blank?
      person_label_fields(attrs[:reviewers_attributes])
      attrs[:reviewer_display] = build_person_display(attrs[:reviewers_attributes])
    end

    if attrs.key?(:translators_attributes) && !attrs[:translators_attributes].blank?
      person_label_fields(attrs[:translators_attributes])
      attrs[:translator_display] = build_person_display(attrs[:translators_attributes])
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
      displays = []
      person_attrs.each do |k,v|
        display_text = []
        display_text << v['name'] if !v['name'].blank?
        display_text << "ORCID: #{v['orcid']}" if !v['orcid'].blank?
        display_text << "Affiliation: #{split_affiliations(v['affiliation']).join(', ')}" if !v['affiliation'].blank?
        display_text << "Other Affiliation: #{v['other_affiliation']}" if !v['other_affiliation'].blank?
        displays << display_text.join('||')
      end
      displays
    end

    def self.person_label_fields(person_attrs)
      person_attrs.each do |k,v|
        if !v['name'].blank?
          @person_label.push(v['name'])
          @orcid_label.push(v['orcid']) if !v['orcid'].blank?
          @affiliation_label.push(split_affiliations(v['affiliation'])) if !v['affiliation'].blank?
          @other_affiliation_label.push(v['other_affiliation']) if !v['other_affiliation'].blank?
        end
      end
    end

    def self.facet_field(person_attrs, person_type)
      person_attrs.each do |k,v|
        if person_type == 'creator'
          @creator_label.push(v['name']) if !v['name'].blank?
        elsif person_type == 'advisor'
          @advisor_label.push(v['name']) if !v['name'].blank?
        end
      end
    end
end