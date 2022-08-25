require 'rails_helper'
require Rails.root.join('app/overrides/jobs/attach_files_to_work_job_override.rb')

RSpec.describe AttachFilesToWorkJob, type: :job do
  let(:user) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:admin) }
  let(:role) { Role.new(name: 'admin') }
  let(:work) {
    Article.create(title: ['New Article'],
      depositor: user.user_key)
  }
  let(:admin_set) { AdminSet.create(title: ['an admin set']) }
  let(:permission_template) { Hyrax::PermissionTemplate.create(source_id: admin_set.id) }
  let(:workflow) { Sipity::Workflow.create(name: 'a workflow', permission_template_id: permission_template.id, active: true) }
  let(:entity) { Sipity::Entity.create(workflow_id: workflow.id, proxy_for_global_id: work.to_global_id.to_s) }
  let(:target_dir) { Dir.mktmpdir }
  let!(:target_file) { Tempfile.create('file.txt', target_dir).path }
  let(:uploaded_file) { Hyrax::UploadedFile.new(user: user, file: File.new(target_file)) }

  before do
    role.users << admin
    role.save
  end

  after do
    FileUtils.rm_rf(target_dir)
  end

  context 'with file containing virus' do
    before do
      # Original method should not be called
      allow(subject).to receive(:original_perform).and_raise('nope')
      allow(Hyc::VirusScanner).to receive(:hyc_infected?).and_return(ClamAV::VirusResponse.new(target_file, 'avirus'))
      # Establish expectation for the following tests that a virus detection notification gets sent
      expect(Hyrax::Workflow::VirusFoundNotification).to receive(:send_notification)
          .with(entity: entity, recipients: anything, comment: anything, user: user)
    end

    it 'sends virus email message' do
      subject.perform(work, [uploaded_file])
      expect(File).not_to exist(target_file)
    end

    context 'that cannot be deleted' do
      before do
        allow(File).to receive(:delete).and_raise(Errno::EACCES)
      end

      it 'still sends virus email message' do
        subject.perform(work, [uploaded_file])
      end
    end
  end

  context 'with safe file' do
    it 'succeeds without any reporting' do
      # Catch expected call to wrapped implementation of perform
      expect(subject).to receive(:original_perform).with(work, [uploaded_file], {})
      expect(Hyc::VirusScanner).to receive(:hyc_infected?).and_return(ClamAV::SuccessResponse.new(target_file))
      subject.perform(work, [uploaded_file])
    end
  end
end
