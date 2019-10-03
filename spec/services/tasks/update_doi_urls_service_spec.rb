require 'rails_helper'

RSpec.describe Tasks::UpdateDoiUrlsService do
  let(:logger) { ActiveSupport::Logger.new('spec/fixtures/files/doi_test.log') }
  let(:params) { {state: 'test', rows: '1', retries: '2', end_date: Date.tomorrow.to_s, log_dir: 'spec/fixtures/files'} }

  after(:all) do
    FileUtils.remove('spec/fixtures/files/doi_test.log')
    FileUtils.remove('spec/fixtures/files/completed_doi_updates.log')
  end

  describe "#initialize" do
    it "sets all params" do
      service = Tasks::UpdateDoiUrlsService.new(params, logger)

      expect(service.state).to eq 'test'
      expect(service.rows).to eq '1'
      expect(service.retries).to eq 2
      expect(service.end_date).to eq Date.tomorrow.to_s
      expect(service.completed_log.as_json['filename']).to eq 'spec/fixtures/files/completed_doi_updates.log'
      expect(service.log).to eq logger
    end
  end

  describe "#update_dois" do
    # make sure there is at least one work with a doi
    let(:approver) { User.find_by_user_key('admin') }
    let(:depositor) { User.create(email: 'test@example.com',
                                  uid: 'test@example.com',
                                  password: 'password',
                                  password_confirmation: 'password') }
    let(:admin_set) do
      AdminSet.create(title: ["article admin set"],
                      description: ["some description"],
                      edit_users: [depositor.user_key])
    end
    let(:work) { HonorsThesis.create(title: ['new article for testing doi updates'],
                                     depositor: depositor.email,
                                     visibility: 'open',
                                     admin_set_id: admin_set.id,
                                     doi: 'https://doi.org/10.5077/test-doi') }
    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
    end
    let(:workflow) do
      Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                              permission_template_id: permission_template.id)
    end
    let(:workflow_state) do
      Sipity::WorkflowState.create(name: 'deposited', workflow_id: workflow.id)
    end

    it "finds and updates dois" do
      # create work with a deposited workflow state
      Sipity::Entity.create(proxy_for_global_id: work.to_global_id.to_s,
                            workflow_id: workflow.id,
                            workflow_state: workflow_state)
      work.save!

      service = Tasks::UpdateDoiUrlsService.new(params, logger)

      stub_request(:any, /datacite/).to_return(body: {data: {id: '10.5077/0001',
                                                              type: 'dois',
                                                              attributes: { doi: 'https://doi.org/10.5077/test-doi'}}}.to_json.to_s)
      expect(service.update_dois).to eql 1
    end
  end
end