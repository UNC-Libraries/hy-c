require 'rails_helper'

RSpec.describe "work_types/index", type: :view do
  before(:each) do
    AdminSet.create(title: ['default'])

    assign(:work_types, [
      WorkType.create!(
        :work_type_name => "some work type",
        :admin_set_id => AdminSet.first.id
      ),
      WorkType.create!(
        :work_type_name => "another work type",
        :admin_set_id => AdminSet.first.id
      )
    ])
  end

  it "renders a list of work_types" do
    render
    assert_select "tr>td", :text => "some work type".to_s, :count => 1
    assert_select "tr>td", :text => "another work type".to_s, :count => 1
    assert_select "tr>td", :text => "default".to_s, :count => 2
  end
end
