# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/services/hyrax/listeners/trophy_cleanup_listener.rb

Hyrax::Listeners::TrophyCleanupListener.class_eval do
  def on_object_deleted(event)
    # [hyc-override] Checking for object key existense before proceeding
    payload = event.payload
    object_id = payload[:object]&.id || payload[:id]
    return if object_id.blank?

    Trophy.where(work_id: object_id).destroy_all
  rescue StandardError => err
    Hyrax.logger.warn "Failed to delete trophies for #{object_id}. " \
                      'These trophies might be orphaned.' \
                      "\n\t#{err.message}"
  end
end
