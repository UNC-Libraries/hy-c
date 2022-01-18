require 'rails_helper'
require 'tasks/migration_helper'

RSpec.describe MigrationHelper do
  describe '#get_uuid_from_path' do
    context 'when a valid path is given' do
      let(:valid_path) { 'lib/tasks/migration/tmp/02002b92-aa8e-4eea-b196-ee951fe7511b/02002b92-aa8e-4eea-b196-ee951fe7511b-DATA_FILE.pdf' }

      it 'returns the uuid' do
        expect(described_class.get_uuid_from_path(valid_path)).to eq '02002b92-aa8e-4eea-b196-ee951fe7511b'
      end
    end

    context 'when an invalid path is given' do
      let(:invalid_path) { 'lib/tasks/migration/tmp/some_file.txt' }

      it 'returns nil' do
        expect(described_class.get_uuid_from_path(invalid_path)).to be_nil
      end
    end
  end

  describe '#create_filepath_hash' do
    let(:filename) { 'spec/fixtures/migration/objects.txt' }
    let(:hash) { Hash.new }
    let(:filepath_hash) do
      {
        '2d005f01-844e-46f3-b528-6a9c40e29914' => 'spec/fixtures/migration/2d005f01-844e-46f3-b528-6a9c40e29914/uuid:2d005f01-844e-46f3-b528-6a9c40e29914-object.xml',
        '2f847077-7060-445b-99b3-190e7cff0067' => 'spec/fixtures/migration/2f847077-7060-445b-99b3-190e7cff0067/uuid:2f847077-7060-445b-99b3-190e7cff0067-object.xml'
      }
    end

    it 'creates a hash of file paths' do
      described_class.create_filepath_hash(filename, hash)
      expect(hash).to eq filepath_hash
    end
  end

  describe '#get_collection_uuids' do
    let(:collection_ids_file) { 'spec/fixtures/migration/collection.csv' }

    it 'creates an array of uuids' do
      expect(described_class.get_collection_uuids(collection_ids_file)).to eq ['2d005f01-844e-46f3-b528-6a9c40e29914']
    end
  end

  describe '#retry_operation' do
    context 'for a failing example' do
      it 'allows method to be retried' do
        retry_result = begin
          described_class.retry_operation('failed') { some_undefined_method_that_will_fail }
        rescue RuntimeError => e
          e.message
        end

        expect(retry_result).to match /could not recover; aborting migration/
      end
    end

    context 'for a successful example' do
      it 'returns method result' do
        retry_result = begin
          described_class.retry_operation('failed') { described_class.get_language_uri(['eng']) }
        rescue StandardError => e
          e.message
        end

        expect(retry_result).to match_array ['http://id.loc.gov/vocabulary/iso639-2/eng']
      end
    end
  end

  describe '#check_enumeration' do
    let(:metadata) do
      {
        'title' => 'a title for an article', # should be array
        'date_issued' => '2019-10-02', # should be string
        'edition' => ['preprint'], # should be string
        'alternative_title' => ['another title for an article'] # should be array
      }
    end
    let(:resource) { Article.new }
    let(:identifier) { 'my new article' }
    let(:formatted_metadata) do
      {
        'title' => ['a title for an article'],
        'date_issued' => '2019-10-02',
        'edition' => 'preprint',
        'alternative_title' => ['another title for an article']
      }
    end

    it 'verifies enumeration of work type attributes' do
      article = described_class.check_enumeration(metadata, resource, identifier)
      article_attributes = article.attributes.delete_if { |_k, v| v.blank? } # remove nil values and empty arrays

      expect(article_attributes).to eq formatted_metadata
    end
  end

  describe '#get_permissions_attributes' do
    let(:admin_set) { AdminSet.new(id: Date.today.to_time.to_i.to_s, title: ['a test admin set']) }
    let(:permission_template) { Hyrax::PermissionTemplate.new(id: Date.today.to_time.to_i, source_id: admin_set.id) }
    let(:manager_group) { Role.new(id: Date.today.to_time.to_i, name: 'manager_group') }
    let(:viewer_group) { Role.new(id: Date.today.to_time.to_i, name: 'viewer_group') }
    let(:manager_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: manager_group.name, proxy_for_type: 'Hyrax::Group') }
    let(:viewer_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: viewer_group.name, proxy_for_type: 'Hyrax::Group') }
    let(:expected_result) do
      [
          { 'type' => 'group', 'name' => manager_group.name, 'access' => 'edit' },
          { 'type' => 'group', 'name' => viewer_group.name, 'access' => 'read' }
      ]
    end

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'group',
                                             agent_id: manager_group.name,
                                             access: 'manage')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'group',
                                             agent_id: viewer_group.name,
                                             access: 'view')
    end

    it 'finds manager and viewer groups for an admin set' do
      expect(described_class.get_permissions_attributes(admin_set.id)).to match_array expected_result
    end
  end

  describe '#get_language_uri' do
    let(:valid_code) { ['ido'] }
    let(:invalid_code) { ['unknown'] }

    context 'with a known code' do
      it 'returns language uri' do
        expect(described_class.get_language_uri(valid_code)).to eq ['http://id.loc.gov/vocabulary/iso639-2/ido']
      end
    end

    context 'with an invalid code' do
      it 'returns the unknown code' do
        expect(described_class.get_language_uri(invalid_code)).to eq invalid_code
      end
    end
  end
end
