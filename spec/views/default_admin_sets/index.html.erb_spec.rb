require 'rails_helper'

RSpec.describe "default_admin_sets/index", type: :view do
  before(:each) do
    assign(:default_admin_sets, [
      DefaultAdminSet.create!(
        :work_type_name => "Work Type Name",
        :admin_set_id => "Admin Set",
        :department => "Department"
      ),
      DefaultAdminSet.create!(
        :work_type_name => "Work Type Name",
        :admin_set_id => "Admin Set",
        :department => "Department"
      )
    ])
  end

  it "renders a list of default_admin_sets" do
    render
    assert_select "tr>td", :text => "Work Type Name".to_s, :count => 2
    assert_select "tr>td", :text => "Admin Set".to_s, :count => 2
    assert_select "tr>td", :text => "Department".to_s, :count => 2
  end
end
