class DefaultAdminSet < ApplicationRecord
  validates :work_type_name, presence: true, uniqueness: { scope: :department }
  validates :admin_set_id, presence: true
end
