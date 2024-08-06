# frozen_string_literal: true
desc 'Update the depositor of a list of objects'
task :set_depositor, [:id_list_file, :depositor_id] => [:environment] do |_t, args|
  Rails.logger.info('Prepapring to run SetDepositorService')
  Tasks::SetDepositorService.run(args[:id_list_file], args[:depositor_id])
end
