# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-role-management/blob/v1.1.0/app/models/concerns/hydra/role_management/user_roles.rb
Hydra::RoleManagement::UserRoles.module_eval do
  # [hyc-override] Add method to check if user has specific manager role
  def admin_unit_manager?(group_name)
    roles.where(name: group_name).exists?
  end
end