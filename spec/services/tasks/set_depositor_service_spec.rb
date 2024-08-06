# frozen_string_literal: true
require 'rails_helper'
include Warden::Test::Helpers

describe Tasks::SetDepositorService, :clean do
  before do
    ActiveFedora::Cleaner.clean!
  end

  let(:depositor1) { FactoryBot.create(:user) }
  let(:depositor2) { FactoryBot.create(:user) }
  let(:depositor3) { FactoryBot.create(:user) }

  let(:admin_set) do
    AdminSet.create(title: ['test admin set'],
                    description: ['some description'])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  let(:work1) do
    Article.create(title: ['Test Article 1'],
                depositor: depositor1.user_key,
                creators_attributes: [{ name: 'Person, Test',
                                        affiliation: 'Department of Biology' }])
  end

  let(:work2) do
    Article.create(title: ['Test Article 2'],
                depositor: depositor2.user_key,
                creators_attributes: [{ name: 'Person, Test',
                                        affiliation: 'Department of Biology' }])
  end

  let(:id_list_file) { Tempfile.new }

  after do
    id_list_file.unlink
  end

  describe '#run' do
    context 'with a list of existing object ids' do
      before do
        File.write(id_list_file, "#{work1.id}\n#{work2.id}")
      end

      it 'updates depositor of a list of objects' do
        Tasks::SetDepositorService.run(id_list_file.path, depositor3.user_key)

        result_work1 = Article.find(work1.id)
        result_work2 = Article.find(work2.id)

        expect(result_work1.depositor).to eq depositor3.user_key
        expect(result_work2.depositor).to eq depositor3.user_key
      end
    end

    context 'with objects that have been deleted' do
      before do
        File.write(id_list_file, "#{work1.id}\n#{work2.id}")
        work1.destroy
      end

      it 'updates depositor of the undeleted object' do
        Tasks::SetDepositorService.run(id_list_file.path, depositor3.user_key)

        result_work2 = Article.find(work2.id)

        expect(result_work2.depositor).to eq depositor3.user_key
      end
    end

    context 'object retrieval throws unexpected error' do
      before do
        File.write(id_list_file, "#{work1.id}\n#{work2.id}")
        allow(ActiveFedora::Base).to receive(:find).with(work1.id).and_raise(ActiveFedora::ModelMismatch)
        allow(ActiveFedora::Base).to receive(:find).with(work2.id).and_return(work2)
      end

      it 'updates depositor of the undeleted object' do
        Tasks::SetDepositorService.run(id_list_file.path, depositor3.user_key)

        result_work2 = Article.find(work2.id)

        expect(result_work2.depositor).to eq depositor3.user_key
      end
    end
  end
end
