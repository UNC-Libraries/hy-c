# frozen_string_literal: true
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/actors/hyrax/actors/interpret_visibility_actor_override.rb')

RSpec.describe Hyrax::Actors::InterpretVisibilityActor do
  let(:user) { FactoryBot.create(:user) }
  let(:ability) { ::Ability.new(user) }
  let(:curation_concern) { Article.new }
  let(:attributes) { { admin_set_id: admin_set.id, permission_template: :permission_template } }
  let(:admin_set) { AdminSet.create(title: ['an admin set']) }
  let(:permission_template) do
    Hyrax::PermissionTemplate.create(
      source_id: admin_set.id,
      release_period: Hyrax::PermissionTemplate::RELEASE_TEXT_VALUE_1_YEAR,
      visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC)
  end
  let(:terminator) { Hyrax::Actors::Terminator.new }
  let(:env) { Hyrax::Actors::Environment.new(curation_concern, ability, attributes) }

  subject(:middleware) do
    stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
      middleware.use described_class
      middleware.use Hyrax::Actors::GenericWorkActor
    end
    stack.build(terminator)
  end

  context "with an admin user" do
    let(:permission_template) do
      Hyrax::PermissionTemplate.create(
             source_id: admin_set.id,
             release_period: Hyrax::PermissionTemplate::RELEASE_TEXT_VALUE_1_YEAR,
             visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC)
    end
    let(:attributes) do
      { title: ['New embargo'],
        admin_set_id: admin_set.id,
        visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_EMBARGO,
        embargo_release_date: one_year_from_today.to_s,
        visibility_after_embargo: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED }
    end

    it "allows the admin user to override the permission template on the visibility field" do
      permission_template.reload
      expect(subject.create(env)).to be true
    end
  end
end
