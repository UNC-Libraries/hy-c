# [hyc-override] Overriding to make depositor a facet search and not link to user profile
# Log new version of a file to activity streams
class ContentNewVersionEventJob < ContentEventJob
  def action
    @action ||= "User #{link_to depositor, main_app.search_catalog_path(f: { depositor_tesim: [depositor]})} has added a new version of #{link_to repo_object.title.first, Rails.application.routes.url_helpers.hyrax_file_set_path(repo_object)}"
  end
end