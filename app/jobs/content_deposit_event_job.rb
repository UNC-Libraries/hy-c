# [hyc-override] Overriding to make depositor a facet search and not link to user profile
# Log a concern deposit to activity streams
class ContentDepositEventJob < ContentEventJob
  def action
    "User #{link_to depositor, main_app.search_catalog_path(f: { depositor_sim: [depositor]})} has deposited #{link_to repo_object.title.first, polymorphic_path(repo_object)}"
  end
end