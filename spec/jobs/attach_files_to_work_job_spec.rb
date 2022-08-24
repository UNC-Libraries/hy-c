require 'rails_helper'

RSpec.describe AttachFilesToWorkJob, type: :job do
  let(:user) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:admin) }
  let(:role) { Role.new(name: 'admin') }
  let(:work) { 
    Article.create(title: ['New Article'],
      depositor: user.user_key) 
  }
  let(:file_set) { FactoryBot.create(:file_set, title: ['test file set']) }
  let(:file_set_actor) { Hyrax::Actors::FileSetActor.new(file_set, user) }
  let(:admin_set) { AdminSet.create(title: ['an admin set']) }
  let(:permission_template) { Hyrax::PermissionTemplate.create(source_id: admin_set.id) }
  let(:workflow) { Sipity::Workflow.create(name: 'a workflow', permission_template_id: permission_template.id, active: true) }
  let(:entity) { Sipity::Entity.create(workflow_id: workflow.id, proxy_for_global_id: work.to_global_id.to_s) }
  let(:target_dir) { Dir.mktmpdir }
  let(:target_file) { Tempfile.new('file.txt', target_dir).path }
  let(:uploaded_file) { Hyrax::UploadedFile.new(user: user, file: File.new(target_file)) }

  before do
    file_set_actor.attach_to_work(work)
    role.users << admin
    role.save
  end

  after do
    FileUtils.rm_rf(target_dir)
  end

  context 'with file containing virus' do
    before do
      expect(Hyc::VirusScanner).to receive(:hyc_infected?).and_return(ClamAV::VirusResponse.new(target_file, 'avirus'))
      expect(Hyrax::Workflow::VirusFoundNotification).to receive(:send_notification)
          .with(entity: entity, recipients: anything, comment: anything, user: user)
    end

    it 'sends virus email message' do
      subject.perform(work, [uploaded_file])
    end
  end

  context 'with safe file' do
    before do
      expect(Hyc::VirusScanner).to receive(:hyc_infected?).and_return(ClamAV::SuccessResponse.new(target_file))
    end

    it 'succeeds without any reporting' do
      subject.perform(work, [uploaded_file])
    end
  end
end