# [hyc-override] Overriding to make depositor a facet search and not link to user profile
# Log file restored version to activity streams
class ContentRestoredVersionEventJob < ContentEventJob
  attr_accessor :revision_id

  def perform(file_set, depositor, revision_id)
    @revision_id = revision_id
    super(file_set, depositor)
  end

  # [hyc-override] Overriding to make depositor a facet search and not link to user profile
  def action
    "User #{link_to depositor, search_catalog_path(f: { depositor_ssim: [depositor.to_s.sub("-dot-", ".")]})} has restored a version '#{revision_id}' of #{link_to repo_object.title.first, Rails.application.routes.url_helpers.hyrax_file_set_path(repo_object)}"
  end
end
