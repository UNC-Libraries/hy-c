require 'rails_helper'

RSpec.describe "default_admin_sets/edit", type: :view do
  before(:each) do
    @default_admin_set = assign(:default_admin_set, DefaultAdminSet.create!(
                                                      :work_type_name => "MyString",
                                                      :admin_set_id => "MyString",
                                                      :department => "MyString"
                                                    ))
    @admin_sets = [['default', 'MyString'], ['some admin set', 'id123456']]
    @work_type_names = ['Work', 'Article', 'MastersPaper']
  end

  it "renders the edit default_admin_set form" do
    render

    assert_select "form[action=?][method=?]", default_admin_set_path(@default_admin_set), "post" do
      assert_select "select#default_admin_set_work_type_name[name=?]", "default_admin_set[work_type_name]"

      assert_select "select#default_admin_set_admin_set_id[name=?]", "default_admin_set[admin_set_id]"

      assert_select "select#default_admin_set_department[name=?]", "default_admin_set[department]"
    end
  end
end
