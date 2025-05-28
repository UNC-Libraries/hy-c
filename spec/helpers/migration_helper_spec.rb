# frozen_string_literal: true
require 'rails_helper'
require 'tasks/migration_helper'

RSpec.describe MigrationHelper do
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
        'alternative_title' => ['another title for an article'],
        'visibility' => 'open'
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
