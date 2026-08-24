# frozen_string_literal: true

# Public authorization service that allows all IIIF image access without authentication
class IiifPublicAuthorizationService
  # Always allow access to IIIF images
  def self.authorize!(*)
    true
  end
end

