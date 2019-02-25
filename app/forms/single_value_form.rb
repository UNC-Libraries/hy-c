# [hyc-override] Overriding work form in hyrax gem to allow default fields to be singular
class SingleValueForm < Hyrax::Forms::WorkForm
  extend Hyc::EdtfConvert

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
        unless attrs.key?(field)
          values = default_term_values[field]

          if attrs[field].blank?
            attrs[field] = values
          end
        end
      end
    end

    if attrs.key?(:language) && !attrs[:language].blank?
      attrs[:language_label] = []
      Array(attrs[:language]).each do |language|
        attrs[:language_label] << LanguagesService.label(language)
      end
    end

    if attrs.key?(:license) && !attrs[:license].blank?
      attrs[:license_label] = []
      Array(attrs[:license]).each do |license|
        attrs[:license_label] << CdrLicenseService.label(license)
      end
    end

    if attrs.key?(:rights_statement) && !attrs[:rights_statement].blank?
      attrs[:rights_statement_label] = CdrRightsStatementsService.label(attrs[:rights_statement])
    end

    attrs.each do |person_key, person_value|
      if person_key.to_s.match('_attributes')
        person_value.each do |k,v|
          if !v['affiliation'].blank?
            v['affiliation'] = v['affiliation']
          end
        end
      end
    end

    # Convert dates from human readable strings to EDTF format
    edtf_form_update(attrs, :date_created)
    edtf_form_update(attrs, :date_issued)

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
end