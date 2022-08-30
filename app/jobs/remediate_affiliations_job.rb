# frozen_string_literal: true
class RemediateAffiliationsJob < Hyrax::ApplicationJob
  queue_as :long_running_jobs

  def perform
    csv_path = Rails.root.join(ENV['DATA_STORAGE'], 'reports', 'unmappable_affiliations.csv').to_s
    service = AffiliationRemediationService.new(csv_path)
    service.remediate_all_affiliations
  end
end
