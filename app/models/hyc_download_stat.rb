# frozen_string_literal: true
class HycDownloadStat < ApplicationRecord
  scope :with_fileset_id_and_date, ->(fileset_id, start_date, end_date) { where(fileset_id: fileset_id, date: start_date..end_date) }
  scope :with_work_id_and_date, ->(work_id, start_date, end_date) { where(work_id: work_id, date: start_date..end_date) }
  scope :with_admin_set_id, ->(admin_set_id) { where(admin_set_id: admin_set_id) }
  scope :with_work_type, ->(work_type) { where(work_type: work_type) }

    # Additional scopes for flexibility
  scope :with_fileset_id, ->(fileset_id) { where(fileset_id: fileset_id) }
  scope :with_work_id, ->(work_id) { where(work_id: work_id) }
  scope :within_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  end
