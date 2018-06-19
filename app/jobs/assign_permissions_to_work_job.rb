# Called by AssignReviewerByAcademicDepartment service
class AssignPermissionsToWorkJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(model, work_id, agent, type, access)
    work = model.constantize.find(work_id)
    work.update permissions_attributes: [{name: agent, type: type, access: access}]
  end
end