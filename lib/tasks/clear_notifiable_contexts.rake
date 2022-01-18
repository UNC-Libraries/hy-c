desc 'Removes all notification contexts'
task clear_notifiable_contexts: :environment do
  Sipity::NotifiableContext.delete_all
  Sipity::NotificationRecipient.delete_all
end
