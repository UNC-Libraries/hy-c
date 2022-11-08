# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::SetupTasksService do
  describe '#admin_role' do
    before do
      User.delete_all
      Role.delete_all
      ActiveFedora::Cleaner.clean!
    end

    it 'creates an admin user in the admin role' do
      expect { Tasks::SetupTasksService.admin_role }.to change { User.count }.by(1).and change { Role.count }.by(1)
      expect(Role.where(name: 'admin').first.users).to match_array [User.last]
    end
  end

  describe '#default_admin_set' do
    before do
      AdminSet.delete_all
      ActiveFedora::Cleaner.clean!
    end

    it 'creates a default admin set' do
      expect { Tasks::SetupTasksService.default_admin_set }.to change { AdminSet.count }.by(1)
    end
  end

  describe '#new_user' do
    it 'creates a new user' do
      expect { Tasks::SetupTasksService.new_user('person1@example.com') }.to change { User.count }.by(1)
      expect(User.where(email: 'person1@example.com').first.uid).to eq 'person1'
    end
  end

  describe '#test_data_import' do
    it 'loads test data' do
      expect { Tasks::SetupTasksService.test_data_import }.to change { Article.count }.by(30)
    end
  end
end
