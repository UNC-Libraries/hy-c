# frozen_string_literal: true
# Special permission template for admin users, indicating they aren't constrained by the admin set's
# release/visibility settings. Used in Hyrax::WorksControllerBehavior#available_admin_sets.
class AdminPermissionTemplate < Hyrax::PermissionTemplate
  def release_no_delay?
    false
  end

  def release_before_date?
    false
  end

  def release_date
    nil
  end

  def visibility
    nil
  end
end
