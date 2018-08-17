# [hyc-override] Overriding work form in hyrax gem to allow default fields to be singular
class SingleValueForm < Hyrax::Forms::WorkForm

  def self.multiple?(field)
    if single_value_fields.include? field.to_sym
      false
    else
      super
    end
  end

  # cast single value fields back to multivalued so they will actually deposit
  # Split out affiliations for deposit and display
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

    # Split out affiliations
    unless !attrs.key?(:affiliation) || attrs[:affiliation].blank?
      affiliations = []

      attrs[:affiliation].each do |aff|
        aff.split(';').each do |value|
          affiliations.push(value)
        end
      end

      attrs[:affiliation] = affiliations.uniq
    end

    attrs
  end
end