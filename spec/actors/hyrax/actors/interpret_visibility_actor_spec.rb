# frozen_string_literal: true
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/actors/hyrax/actors/interpret_visibility_actor_override.rb')

RSpec.describe Hyrax::Actors::InterpretVisibilityActor do
  let(:regular_user) { FactoryBot.create(:user) }
  let(:admin_user) { FactoryBot.create(:admin) }
  let(:curation_concern) { Article.new }
  let(:admin_set) { AdminSet.create(
    title: ['an admin set']) }

  let(:terminator) { Hyrax::Actors::Terminator.new }
  let(:env) { Hyrax::Actors::Environment.new(curation_concern, ability, attributes) }
  let(:one_year_from_today) { Time.zone.today + 1.year }
  let(:two_years_from_today) { Time.zone.today + 2.year }

  subject(:middleware) do
    stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
      middleware.use described_class
      middleware.use Hyrax::Actors::GeneralActor
    end
    stack.build(terminator)
  end

  context 'with 2 year embargo' do
    let(:attributes) do
      { title: ['New embargo'],
        admin_set_id: admin_set.id,
        visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_EMBARGO,
        visibility_during_embargo: 'authenticated',
        embargo_release_date: two_years_from_today.to_s,
        visibility_after_embargo: 'open' }
    end

    context 'with permission template with no embargo restrictions' do
      let!(:permission_template) do 
        Hyrax::PermissionTemplate.create!(
          source_id: admin_set.id
        )
      end

      context "with an admin user" do
        let(:ability) { ::Ability.new(admin_user) }

        it 'allows admin user to set embargo' do
          expect(subject.create(env)).to be_truthy
          expect(curation_concern.visibility_during_embargo).to eq 'authenticated'
          expect(curation_concern.visibility_after_embargo).to eq 'open'
          expect(curation_concern.visibility).to eq 'authenticated'
        end
      end

      context "with an regular user" do
        let(:ability) { ::Ability.new(regular_user) }

        it 'allows regular user to set embargo' do
          expect(subject.create(env)).to be_truthy
          expect(curation_concern.visibility_during_embargo).to eq 'authenticated'
          expect(curation_concern.visibility_after_embargo).to eq 'open'
          expect(curation_concern.visibility).to eq 'authenticated'
        end
      end
    end

    context 'with permission template limiting embargo dates to 1 year in the future' do
      let!(:permission_template) do 
        Hyrax::PermissionTemplate.create!(
          source_id: admin_set.id,
          release_period: Hyrax::PermissionTemplate::RELEASE_TEXT_VALUE_FIXED,
          release_date: one_year_from_today
        )
      end

      context "with an admin user" do
        let(:ability) { ::Ability.new(admin_user) }

        it 'allows admin user to set embargo' do
          expect(subject.create(env)).to be_truthy
          expect(curation_concern.visibility_during_embargo).to eq 'authenticated'
        end
      end

      context "with an regular user" do
        let(:ability) { ::Ability.new(regular_user) }

        it 'prevents regular user from setting embargo' do
          expect(subject.create(env)).to be_falsey
        end
      end
    end
  end
end
