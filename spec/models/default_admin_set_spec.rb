require 'rails_helper'

RSpec.describe DefaultAdminSet, type: :model do
  subject {
    described_class.new(work_type_name: 'an admin set', admin_set_id: 'id123456')
  }

  it 'is valid with valid attributes' do
    expect(subject).to be_valid
  end

  it 'is not valid without a work_type_name' do
    subject.work_type_name = nil
    expect(subject).to_not be_valid
  end

  it 'is not valid without an admin_set_id' do
    subject.admin_set_id = nil
    expect(subject).to_not be_valid
  end

  it { should validate_uniqueness_of(:work_type_name).scoped_to(:department) }
end
