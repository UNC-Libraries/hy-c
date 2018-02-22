class AdminSetSelectService
  # This method selects an admin set based on a model type. By passing in the
  # model and the select options, the method can look at the configuration and
  # make a decision about what admin set to use.
  # Inputs: Model, Select Options
  # Output: Array with stingified admin set name ["Article"]
  def self.select(model, select_options)
    default_admin_set = DefaultAdminSet.where(work_type_name: model)
    admin_set_id = ''
    unless default_admin_set.blank?
      admin_set_id = default_admin_set.first.admin_set_id
    end
    mapped_admin_set = select_options.find { |o| o.second.casecmp(admin_set_id).zero? }
    [ mapped_admin_set || select_options.find { |o| o.first.casecmp(ENV["DEFAULT_ADMIN_SET"]).zero? } ].flatten
  end
end