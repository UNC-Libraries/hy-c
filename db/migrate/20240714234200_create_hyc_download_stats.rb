class CreateHycDownloadStats < ActiveRecord::Migration[6.1]
  def change
    create_table :hyc_download_stats do |t|
      t.string :fileset_id, null: false
      t.string :work_id, null: false
      t.string :admin_set_id, null: false
      t.string :work_type, null: false
      t.date :date, null: false
      t.integer :download_count, default: 0, null: false

      t.timestamps
    end

    add_index :hyc_download_stats, [:fileset_id, :date]
    add_index :hyc_download_stats, [:work_id, :date]
    add_index :hyc_download_stats, :admin_set_id
    add_index :hyc_download_stats, :work_type
  end
end
