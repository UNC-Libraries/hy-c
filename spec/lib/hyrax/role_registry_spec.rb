# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::RoleRegistry do
  let(:existing_role) { Sipity::Role.create!(name: 'managing', description: 'test-description') }

  describe '#persist_registered_roles!' do

    it 'creates roles if they do not exist' do
      expect { subject.persist_registered_roles! }
    .to change { Sipity::Role.count }.by(4)
      expect(Sipity::Role.exists?(name: 'managing')).to be true
      expect(Sipity::Role.exists?(name: 'approving')).to be true
      expect(Sipity::Role.exists?(name: 'depositing')).to be true
      expect(Sipity::Role.exists?(name: 'viewing')).to be true
    end

    it 'does not create roles if they already exist' do
      existing_role
      expect { subject.persist_registered_roles! }
  .to change { Sipity::Role.count }.by(3)
    end

    it 'updates the description of existing roles' do
      existing_role
      subject.persist_registered_roles!
      expect(Sipity::Role.find_by(name: 'managing').description).to eq 'Grants access to management tasks'
    end
  end
end
