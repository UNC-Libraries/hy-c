require 'rails_helper'

RSpec.describe 'default_admin_sets/index', type: :view do
  before(:each) do
    admin_set = AdminSet.create(title: ['index view admin set'])
    assign(:default_admin_sets, [
      DefaultAdminSet.create!(
        work_type_name: 'Work Type Name',
        admin_set_id: admin_set.id,
        department: 'Department'
      ),
      DefaultAdminSet.create!(
        work_type_name: 'Work Type Name2',
        admin_set_id: admin_set.id,
        department: 'Department'
      )
    ])
  end

  it 'renders a list of default_admin_sets' do
    render
    assert_select 'tr>td', text: 'Work Type Name'.to_s, count: 1
    assert_select 'tr>td', text: 'Work Type Name2'.to_s, count: 1
    assert_select 'tr>td', text: 'index view admin set'.to_s, count: 2
    assert_select 'tr>td', text: 'Department'.to_s, count: 2
  end
end
