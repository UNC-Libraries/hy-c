# [hyc-override] add virus checking to job
# Converts UploadedFiles into FileSets and attaches them to works.
class AttachFilesToWorkJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  # @param [ActiveFedora::Base] work - the work object
  # @param [Array<Hyrax::UploadedFile>] uploaded_files - an array of files to attach
  def perform(work, uploaded_files, **work_attributes)
    validate_files!(uploaded_files)
    depositor = proxy_or_depositor(work)
    user = User.find_by_user_key(depositor)
    work_permissions = work.permissions.map(&:to_hash)
    metadata = visibility_attributes(work_attributes)
    uploaded_files.each do |uploaded_file|
      # [hyc-override] check all files for viruses
      virus_check!(uploaded_file)
      next if uploaded_file.file_set_uri.present?

      actor = Hyrax::Actors::FileSetActor.new(FileSet.create, user)
      uploaded_file.update(file_set_uri: actor.file_set.uri)
      actor.file_set.permissions_attributes = work_permissions
      actor.create_metadata(metadata)
      actor.create_content(uploaded_file)
      actor.attach_to_work(work)
    end
  # [hyc-override] Log viruses
  rescue VirusDetectedError => error
    message = "Virus encountered while processing file #{error.filename} for work #{work.id}. Virus signature: #{error.scan_results.virus_name}"
    send_email_about_virus(work, message, user) && (Rails.logger.error message)
  end

  # [hyc-override] Add virus detection error class
  class VirusDetectedError < RuntimeError
    attr_reader :scan_results, :filename

    def initialize(scan_results, filename)
      @scan_results = scan_results
      @filename = filename
    end
  end

  private

  # The attributes used for visibility - sent as initial params to created FileSets.
  def visibility_attributes(attributes)
    attributes.slice(:visibility, :visibility_during_lease,
                     :visibility_after_lease, :lease_expiration_date,
                     :embargo_release_date, :visibility_during_embargo,
                     :visibility_after_embargo)
  end

  def validate_files!(uploaded_files)
    uploaded_files.each do |uploaded_file|
      next if uploaded_file.is_a? Hyrax::UploadedFile
      raise ArgumentError, "Hyrax::UploadedFile required, but #{uploaded_file.class} received: #{uploaded_file.inspect}"
    end
  end

  ##
  # A work with files attached by a proxy user will set the depositor as the intended user
  # that the proxy was depositing on behalf of. See tickets #2764, #2902.
  def proxy_or_depositor(work)
    work.on_behalf_of.blank? ? work.depositor : work.on_behalf_of
  end

  # [hyc-override] add virus checking method
  def virus_check!(uploaded_file)
    file_path = uploaded_file.file.to_s
    scan_results = Hyc::VirusScanner.hyc_infected?(file_path)
    return if scan_results.instance_of? ClamAV::SuccessResponse
    if scan_results.instance_of? ClamAV::VirusResponse
      FileUtils.rm_rf(File.dirname(file_path))
      raise VirusDetectedError.new(scan_results, file_path)
    end
  end

  # [hyc-override] Send notification to depositors and repo admins
  def send_email_about_virus(work, file, depositor)
    entity = Sipity::Entity.where(proxy_for_global_id: work.to_global_id.to_s).first
    recipients = Hash.new
    recipients[:to] = Role.where(name: 'admin').first.users
    agent = Sipity::Agent.where(proxy_for_id: depositor.id, proxy_for_type: 'User').first_or_create
    comment = Sipity::Comment.create(entity_id: entity.id, agent_id: agent.id, comment: file)
    Hyrax::Workflow::VirusFoundNotification.send_notification(entity: entity,
                                                              comment: comment,
                                                              user: depositor,
                                                              recipients: recipients)
  end
end
