# [hyc-override] Overriding work form in hyrax gem to allow default fields to be singular
class SingleValueForm < Hyrax::Forms::WorkForm
  
  # Field which will not be rendered to the work form
  class_attribute :admin_only_terms
  self.admin_only_terms = Array.new
  # Map of fields to default values
  class_attribute :default_term_values
  self.default_term_values = Hash.new
  
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

    # Split out affiliations
    unless !attrs.key?(:affiliation) || attrs[:affiliation].blank?
      affiliations = []

      attrs[:affiliation].each do |aff|
        aff.split(';').each do |value|
          affiliations.push(value.squish!)
        end
      end

      attrs[:affiliation] = affiliations.uniq
    end

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
        if single_value_fields.include? field.to_sym
          if model[field].blank?
            model[field].set(values.first)
          end
        else
          if model[field].blank?
            model[field].set(values)
          end
        end
      end
    end
end