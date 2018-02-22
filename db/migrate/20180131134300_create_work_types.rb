class CreateWorkTypes < ActiveRecord::Migration[5.0]
  def change
    create_table :work_types do |t|
      t.string :work_type_name, unique: true
      t.string :admin_set_id

      t.timestamps
    end
  end
end
