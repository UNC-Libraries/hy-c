class CreateDefaultAdminSets < ActiveRecord::Migration[5.0]
  def change
    create_table :default_admin_sets do |t|
      t.string :work_type_name
      t.string :admin_set_id
      t.string :department, default: ""

      t.timestamps
    end
  end
end
