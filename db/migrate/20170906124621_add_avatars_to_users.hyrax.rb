# frozen_string_literal: true
# This migration comes from hyrax (originally 20160328222158)
class AddAvatarsToUsers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, 'avatar_file_name',    :string
    add_column :users, 'avatar_content_type', :string
    add_column :users, 'avatar_file_size',    :integer
    add_column :users, 'avatar_updated_at',   :datetime
  end

  def self.down
    remove_column :users, 'avatar_file_name'
    remove_column :users, 'avatar_content_type'
    remove_column :users, 'avatar_file_size'
    remove_column :users, 'avatar_updated_at'
  end
end
