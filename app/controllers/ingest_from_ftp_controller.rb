# frozen_string_literal: true
class IngestFromFtpController < ApplicationController
  before_action :ensure_admin!
  layout 'hyrax/dashboard'

  def list_packages
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb 'Ingest From FTP', request.path

    @package_results = build_package_listing
    @needs_revision_flag = needs_revision_flag?
  end

  def ingest_packages
    # Prepopulate statuses for packages so we can immediately view a report
    ingest_status_service.initialize_statuses(list_package_files.map { |f| File.basename(f) })
    if provider == 'proquest'
      IngestFromProquestJob.perform_later
    else
      IngestFromSageJob.perform_later
    end
    redirect_to ingest_from_ftp_status_path(provider: @provider)
  end

  def view_status
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb 'Ingest From FTP status', ingest_from_ftp_path
    add_breadcrumb 'Ingest status', request.path
    statuses = ingest_status_service.load_statuses || {}
    @status_results = statuses.sort.to_h
  end

  private

  def list_package_files
    Dir[File.join(storage_base_path, '*.zip')]
  end

  def build_package_listing
    package_results = []
    list_package_files.each do |filename|
      result = {
        filename: File.basename(filename),
        last_modified: File.ctime(filename)
      }
      result[:is_revision] = is_revision?(filename) if needs_revision_flag?
      package_results << result
    end
    package_results.sort_by { |result| result[:filename] }
  end

  def provider
    @provider ||= params[:provider].blank? ? 'proquest' : params[:provider]
  end

  def ingest_status_service
    @ingest_status_service ||= Tasks::IngestStatusService.status_service_for_provider(provider)
  end

  def storage_base_path
    if provider == 'proquest'
      base_path = ENV['INGEST_PROQUEST_PATH']
    else
      base_path = ENV['INGEST_SAGE_PATH']
    end
  end

  def needs_revision_flag?
    @needs_flag ||= provider == 'sage'
  end

  def is_revision?(filename)
    File.basename(filename).match?(/\.r[0-9]{4}-[0-9]{2}-[0-9]{2}/)
  end

  def ensure_admin!
    authorize! :read, :admin_dashboard
  end
end
