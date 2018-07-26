class AdminSetSelectService
  # This method selects an admin set based on a model type. By passing in the
  # model and the select options, the method can look at the configuration and
  # make a decision about what admin set to use.
  # Inputs: Model, Affiliation, Select Options
  # Output: Array with stingified admin set name ["Article"]
  def self.select(model, affiliation, select_options)
    # Check to see if there is a default admin set for work type
    default_admin_set = DefaultAdminSet.where(work_type_name: model, department: affiliation)
    if default_admin_set.blank?
      default_admin_set = DefaultAdminSet.where(work_type_name: model, department: '')
    end

    # Select default admin set for work type or use the system default admin set
    admin_set_id = ''
    if !default_admin_set.blank?
      admin_set_id = default_admin_set.first.admin_set_id
    else
      admin_set_id = (AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first || AdminSet.first).id
    end

    # Return admin set id
    admin_set_id
  end
end
