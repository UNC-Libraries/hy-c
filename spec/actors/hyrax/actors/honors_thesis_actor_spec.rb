# frozen_string_literal: true
require 'rails_helper'
require 'active_fedora/cleaner'

# Load the override being tested
require Rails.root.join('app/overrides/actors/hyrax/actors/base_actor_override.rb')

RSpec.describe Hyrax::Actors::HonorsThesisActor do
  before do
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
  end

  let(:depositor) {
    User.create(email: 'test_depositor@example.com',
                uid: 'test_depositor',
                password: 'password',
                password_confirmation: 'password')
  }

  let(:admin_set) do
    AdminSet.create(title: ['honors admin set'],
                    description: ['some description'],
                    edit_users: [depositor.user_key])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  let(:ability) { ::Ability.new(depositor) }

  before do
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?).and_return(false)
    Sipity::WorkflowState.create(workflow_id: workflow.id, name: 'deposited')
  end

  let(:curation_concern) {
    HonorsThesis.create(title: ['new honors thesis'],
                        depositor: depositor.email,
                        admin_set_id: admin_set.id)
  }
  let(:file_set) { FactoryBot.create(:file_set, :with_original_file, title: ['Should have file']) }
  let!(:entity) { Sipity::Entity.create(proxy_for_global_id: curation_concern.to_global_id.to_s, workflow_id: workflow.id) }

  before do
    curation_concern.ordered_members << file_set
    curation_concern.save!
  end

  let(:env) { Hyrax::Actors::Environment.new(curation_concern, ability, attributes) }

  describe '#update' do
    subject { Hyrax::CurationConcern.actor }

    context 'with user permissions' do
      let(:attributes) {
        {
          permissions_attributes: {
            "0": {
              type: 'person',
              name: 'test_depositor@example.com',
              access: 'edit'
            }
          }
        }
      }

      it 'assigns user agent permissions' do
        subject.update(env)

        approver_perm = curation_concern.permissions.to_a.find { |perm| perm.agent.first.id == 'http://projecthydra.org/ns/auth/person#test_depositor' }
        expect(approver_perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Write'
      end
    end

    context 'with group permissions' do
      let(:attributes) {
        {
          permissions_attributes: {
            "0": {
              type: 'group',
              name: 'agroup',
              access: 'read'
            }
          }
        }
      }

      it 'assigns group agent permissions' do
        subject.update(env)

        reader_perm = curation_concern.permissions.to_a.find { |perm| perm.agent.first.id == 'http://projecthydra.org/ns/auth/group#agroup' }
        expect(reader_perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Read'
      end
    end

    context 'with blank permissions' do
      let(:attributes) {
        {
          permissions_attributes: {}
        }
      }

      it 'does not assign permissions' do
        expect(Hyrax::Workflow::PermissionGenerator).not_to receive(:call)

        subject.update(env)

        expect(curation_concern.permissions.to_a).to be_empty
      end
    end

    # Relates to cleaning up permissions before assigning
    context 'with permission index' do
      let(:attributes) {
        {
          permissions_attributes: {
            '0': {
              index: '0',
              type: 'person',
              name: 'test_depositor@example.com',
              access: 'edit'
            }
          }
        }
      }

      it 'assigns user agent permissions' do
        subject.update(env)

        approver_perm = curation_concern.permissions.to_a.find { |perm| perm.agent.first.id == 'http://projecthydra.org/ns/auth/person#test_depositor' }
        expect(approver_perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Write'
      end
    end

    context 'with added person object' do
      let(:attributes) {
        {
          creators_attributes: { '0' => { name: 'creator person',
                                          affiliation: 'biology' } }
        }
      }

      it 'saves person details to work' do
        subject.update(env)

        first_creator = curation_concern.creators.first
        expect(first_creator.attributes['name']).to eq(['creator person'])
        expect(first_creator.attributes['affiliation']).to eq(['biology'])
      end
    end

    context 'with deleted person' do
      let(:curation_concern) {
        HonorsThesis.create(title: ['new honors thesis'],
                            depositor: depositor.email,
                            creators_attributes: { '0' => { name: 'creator hyc',
                                            affiliation: 'biology' } },
                            admin_set_id: admin_set.id)
      }

      let(:attributes) {
        {
          creators_attributes: { '0' => { name: 'creator hyc',
                                          affiliation: 'biology',
                                          _destroy: true } }
        }
      }

      it 'logs the id of the work containing the deleted person' do
        subject.update(env)

        File.open(ENV['DELETED_PEOPLE_FILE'], 'r') do |file|
          expect(file.read).to include(curation_concern.id)
        end
      end
    end
  end

  describe '#create' do
    subject { Hyrax::CurationConcern.actor }

    let(:terminator) { Hyrax::Actors::Terminator.new }

    subject(:middleware) do
      stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
        middleware.use Hyrax::Actors::CreateWithFilesActor
        middleware.use Hyrax::Actors::AddToWorkActor
        middleware.use Hyrax::Actors::InterpretVisibilityActor
        middleware.use described_class
      end
      stack.build(terminator)
    end

    before do
      allow(terminator).to receive(:create).and_return(true)
    end

    context 'with user permissions' do
      let(:attributes) {
        {
          permissions_attributes: {
            "0": {
              type: 'person',
              name: 'test_depositor@example.com',
              access: 'edit'
            }
          }
        }
      }

      it 'assigns user agent permissions' do
        middleware.create(env)

        approver_perm = curation_concern.permissions.to_a.find { |perm| perm.agent.first.id == 'http://projecthydra.org/ns/auth/person#test_depositor' }
        expect(approver_perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Write'
      end
    end
  end

  def expect_create_workflow_permissions_called(entity, permission, workflow)
    expect_any_instance_of(Hyrax::Actors::BaseActor).to receive(:create_workflow_permissions)
        .with(entity, anything, permission, workflow)
  end
end
