class DefaultAdminSet < ApplicationRecord
  validates :work_type_name, uniqueness: true, presence: true
  validates :admin_set_id, presence: true
end
