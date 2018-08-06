# [hyc-override] Overriding work form in hyrax gem to allow default fields to be singular
class SingleValueForm < Hyrax::Forms::WorkForm
  
  # Field which will not be rendered to the work form
  class_attribute :suppressed_terms
  self.suppressed_terms = Array.new
  # Map of fields to fixed values for those fields, which will override any value assigned
  class_attribute :fixed_term_values
  self.fixed_term_values = Hash.new

  def self.multiple?(field)
    if single_value_fields.include? field.to_sym
      false
    else
      super
    end
  end

  # cast single value fields back to multivalued so they will actually deposit
  def self.model_attributes(_)
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
    
    # Insert fixed values, overriding any already defined values
    fixed_term_values.each do |field, values|
      if multiple? field
        attrs[field] = values
      else
        if single_value_fields.include? field
          attrs[field] = [values.first]
        else
          attrs[field] = values.first
        end
      end
    end

    attrs
  end
  
  def secondary_terms
    super - suppressed_terms
  end
end