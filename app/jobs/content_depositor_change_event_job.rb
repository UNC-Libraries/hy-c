# [hyc-override] Overriding to make depositor a facet search and not link to user profile
# Log work depositor change to activity streams
#
# @attr [Boolean] reset (false) should the access controls be reset. This means revoking edit access from the depositor
class ContentDepositorChangeEventJob < ContentEventJob
  include Rails.application.routes.url_helpers
  include ActionDispatch::Routing::PolymorphicRoutes

  attr_accessor :reset

  # @param [ActiveFedora::Base] work the work to be transfered
  # @param [User] user the user the work is being transfered to.
  # @param [TrueClass,FalseClass] reset (false) if true, reset the access controls. This revokes edit access from the depositor
  def perform(work, user, reset = false)
    @reset = reset
    super(work, user)
  end

  # [hyc-override] Overriding to make depositor a facet search and not link to user profile
  def action
    "User #{link_to work.proxy_depositor, search_catalog_path(f: { depositor_tesim: [work.proxy_depositor]})} has transferred #{link_to_work work.title.first} to user #{link_to_profile depositor}"
  end

  def link_to_work(text)
    link_to text, polymorphic_path(work)
  end

  # Log the event to the work's stream
  def log_work_event(work)
    work.log_event(event)
  end
  alias log_file_set_event log_work_event

  def work
    @work ||= Hyrax::ChangeContentDepositorService.call(repo_object, depositor, reset)
  end

  # overriding default to log the event to the depositor instead of their profile
  def log_user_event(depositor)
    # log the event to the proxy depositor's profile
    proxy_depositor.log_profile_event(event)
    depositor.log_event(event)
  end

  def proxy_depositor
    @proxy_depositor ||= ::User.find_by_user_key(work.proxy_depositor)
  end
end
