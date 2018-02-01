require 'rails_helper'

RSpec.describe "work_types/edit", type: :view do
  before(:each) do
    @work_types = assign(:work_type, [WorkType.create!(
      :work_type_name => "MyString",
      :admin_set_id => "MyString"
    )])
    @admin_sets = [['default', 'MyString'], ['some admin set', 'id123456']]
  end

  it "renders the edit work_type form" do
    render

    assert_select "form[action=?][method=?]", update_work_types_path, "post" do
      assert_select "input#work_types_#{@work_types[0].id}_work_type_name[name=?]",
                    "work_types[#{@work_types[0].id}][work_type_name]"

      assert_select "select#work_types_#{@work_types[0].id}_admin_set_id[name=?]",
                    "work_types[#{@work_types[0].id}][admin_set_id]"
    end
  end
end
