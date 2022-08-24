# https://github.com/samvera/hyrax/blob/v2.9.6/app/jobs/attach_files_to_work_job.rb
Hyrax::AttachFilesToWorkJob.class_eval do
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

  # [hyc-override] add virus checking method
  def virus_check!(uploaded_file)
    file_path = URI.unescape(uploaded_file.file.to_s)
    scan_results = Hyc::VirusScanner.hyc_infected?(file_path)
    return if scan_results.instance_of? ClamAV::SuccessResponse

    if scan_results.instance_of? ClamAV::VirusResponse
      File.delete(file_path)
      # Delete the parent directory if it is empty
      parent_dir = File.dirname(file_path)
      Dir.rmdir(parent_dir) if Dir.empty?(parent_dir)
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