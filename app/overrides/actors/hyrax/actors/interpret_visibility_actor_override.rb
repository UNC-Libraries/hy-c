# frozen_string_literal: true
# [hyc-override] Overriding actor to allow admins to override admin set embargo permissions
Hyrax::Actors::InterpretVisibilityActor class_eval do
  private

  # Validate the selected release settings against template, checking for when embargoes/leases are not allowed
  def validate_release_type(env, intention, template)
    # [hyc-override] Overriding actor to allow admins to create embargoes even if not allowed by the admin set policy
    return true if env.current_ability.admin?
    # It's valid as long as embargo is not specified when a template requires no release delays
    return true unless intention.wants_embargo? && template.present? && template.release_no_delay?

    env.curation_concern.errors.add(:visibility, 'Visibility specified does not match permission template "no release delay" requirement for selected AdminSet.')
    false
  end

  # Validate visibility complies with AdminSet template requirements
  def validate_visibility(env, attributes, template)
    # Added this to allow saving of overridden visibility settings in admin set
    return true if env.current_ability.admin? || env.current_ability.can?(:edit, env.curation_concern.id)
    # NOTE: For embargo/lease, attributes[:visibility] will be nil (see sanitize_params), so visibility will be validated as part of embargo/lease
    return true if attributes[:visibility].blank?

    # Validate against template's visibility requirements
    return true if validate_template_visibility(attributes[:visibility], template)

    env.curation_concern.errors.add(:visibility, 'Visibility specified does not match permission template visibility requirement for selected AdminSet.')
    false
  end

  # Validate an embargo date against permission template restrictions
  def valid_template_embargo_date?(env, date, template)
    # Added this to allow admins to override embargo settings in admin set
    return true if env.current_ability.admin?

    return true if template.blank?

    # Validate against template's release_date requirements
    return true if template.valid_release_date?(date)

    env.curation_concern.errors.add(:embargo_release_date, 'Release date specified does not match permission template release requirements for selected AdminSet.')
    false
  end
end