# [hyc-override] Overriding to make depositor a facet search and not link to user profile
# Log content update to activity streams
class ContentUpdateEventJob < ContentEventJob
  def action
    "User #{link_to depositor, main_app.search_catalog_path(f: { depositor_tesim: [depositor]})} has updated #{link_to repo_object.title.first, polymorphic_path(repo_object)}"
  end
end