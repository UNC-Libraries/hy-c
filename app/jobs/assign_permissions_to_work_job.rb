# Called by AssignReviewerByAffiliation service
class AssignPermissionsToWorkJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(model, work_id, group_name, type, access)
    # Update work permissions
    work = model.constantize.find(work_id)
    work.update permissions_attributes: [{name: group_name, type: type, access: access}]

    # Send notification to reviewer group
    entity = Sipity::Entity.where(proxy_for_global_id: work.to_global_id.to_s).first
    recipients = Hash.new
    recipients[:to] = Role.where(name: group_name).first.users

    if recipients[:to].count > 0
      depositor = User.find_by_user_key(work.depositor)
      Hyrax::Workflow::PendingReviewNotification.send_notification(entity: entity,
                                                                   comment: '',
                                                                   user: depositor,
                                                                   recipients: recipients)
    end
  end
end