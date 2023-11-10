# frozen_string_literal: true
desc 'Remediate missing group permission assignments based on permissions of an admin set'
task :remediate_group_permissions, [:id_list_file, :admin_set_id] => [:environment] do |_t, args|
  Rails.logger.warn('Prepapring to run GroupPermissionRemediationService')
  Tasks::GroupPermissionRemediationService.run(args[:id_list_file], args[:admin_set_id])
end
