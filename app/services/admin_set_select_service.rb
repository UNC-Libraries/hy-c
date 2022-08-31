# frozen_string_literal: true
class AdminSetSelectService
  # This method selects an admin set based on a model type. By passing in the
  # model and the select options, the method can look at the configuration and
  # make a decision about what admin set to use.
  # Inputs: Model, Affiliation, Select Options
  # Output: Array with stingified admin set name ["Article"]
  def self.select(model, affiliation, select_options)
    # Check to see if there is a default admin set for work type
    default_admin_set = DefaultAdminSet.where(work_type_name: model, department: affiliation)
    default_admin_set = DefaultAdminSet.where(work_type_name: model, department: '') if default_admin_set.blank?

    # Select default admin set for work type
    admin_set_id = ''
    admin_set_id = default_admin_set.first.admin_set_id unless default_admin_set.blank?

    # Use work type's default if available
    if select_options.find { |o| o.second.casecmp(admin_set_id).zero? }
      admin_set_id
    else
      (AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first || AdminSet.first).id
    end
  end
end
