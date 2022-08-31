# frozen_string_literal: true
# Called by AssignReviewerByAffiliation service
class AssignPermissionsToWorkJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(model, work_id, group_name, type, access)
    # Update work permissions
    work = model.constantize.find(work_id)
    work.update permissions_attributes: [{ name: group_name, type: type, access: access }]

    # Send notification to reviewer group
    entity = Sipity::Entity.where(proxy_for_global_id: work.to_global_id.to_s).first
    recipients = Hash.new
    selected_role = Role.where(name: group_name).first
    if !selected_role.nil?
      recipients[:to] = selected_role.users
    else
      Rails.logger.warn "No users found for role: #{group_name} on work: #{work_id}"
      return
    end

    if recipients[:to].count.positive?
      depositor = User.find_by_user_key(work.depositor)
      Hyrax::Workflow::HonorsDepartmentReviewerDepositNotification.send_notification(entity: entity,
                                                                                     comment: '',
                                                                                     user: depositor,
                                                                                     recipients: recipients)
    end
  end
end
