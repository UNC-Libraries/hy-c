# frozen_string_literal: true
# [hyc-override] Overriding actor to allow admins to override admin set embargo permissions
Hyrax::Actors::InterpretVisibilityActor.class_eval do
  private

  alias_method :original_validate_release_type, :validate_release_type
  # Validate the selected release settings against template, checking for when embargoes/leases are not allowed
  def validate_release_type(env, intention, template)
    # [hyc-override] Overriding actor to allow admins to create embargoes even if not allowed by the admin set policy
    return true if env.current_ability.admin?
    original_validate_release_type(env, intention, template)
  end

  alias_method :original_validate_visibility, :validate_visibility
  # Validate visibility complies with AdminSet template requirements
  def validate_visibility(env, attributes, template)
    # Added this to allow saving of overridden visibility settings in admin set
    return true if env.current_ability.admin? || env.current_ability.can?(:edit, env.curation_concern.id)
    original_validate_visibility(env, attributes, template)
  end

  alias_method :original_valid_template_embargo_date?, :valid_template_embargo_date?
  # Validate an embargo date against permission template restrictions
  def valid_template_embargo_date?(env, date, template)
    # Added this to allow admins to override embargo settings in admin set
    return true if env.current_ability.admin?
    original_valid_template_embargo_date?(env, date, template)
  end
end
