class AddDepartmentToWorkTypes < ActiveRecord::Migration[5.0]
  def change
    add_column :work_types, :department, :string
  end
end
