class ChangeEntityIdToInteger < ActiveRecord::Migration[5.0]
  def self.up
    change_column :sipity_entity_specific_responsibilities, :entity_id, 'integer USING CAST(entity_id AS integer)'
  end
  def self.down
    change_column :sipity_entity_specific_responsibilities, :entity_id, :string
  end
end
