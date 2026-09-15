# frozen_string_literal: true
# [hyc-override] Overriding actor to allow admins to override admin set embargo permissions
module InterpretVisibilityOverrides
  private

  # [hyc-override] Overriding actor to allow admins to create embargoes even if not allowed by the admin set policy
  # Validate the selected release settings against template, checking for when embargoes/leases are not allowed
  def validate_release_type(env, intention, template)
    return true if env.current_ability.admin?
    super
  end

  # Validate visibility complies with AdminSet template requirements
  def validate_visibility(env, attributes, template)
    return true if env.current_ability.admin? || env.current_ability.can?(:edit, env.curation_concern.id)
    super
  end

  # Validate an embargo date against permission template restrictions
  def valid_template_embargo_date?(env, date, template)
    return true if env.current_ability.admin?
    super
  end
end
Hyrax::Actors::InterpretVisibilityActor.prepend(InterpretVisibilityOverrides) unless
  Hyrax::Actors::InterpretVisibilityActor.ancestors.include?(InterpretVisibilityOverrides)
