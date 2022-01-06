# [hyc-override] Adding permissions to admin group
class Ability
  include Hydra::Ability
  
  include Hyrax::Ability
  self.ability_logic += [:everyone_can_create_curation_concerns]

  # Define any customized permissions here.
  def custom_permissions
    if current_user.admin?
      can [:create, :show, :add_user, :remove_user, :index, :edit, :update, :destroy], Role
      can :manage, User
    end
    # Limits deleting objects to a the admin user
    #
    # if current_user.admin?
    #   can [:destroy], ActiveFedora::Base
    # end

    # Limits creating new objects to a specific group
    #
    # if user_groups.include? 'special_group'
    #   can [:create], ActiveFedora::Base
    # end
  end

  private

    # [hyc-override] Overriding review ability to include entity-specific permissions
    def can_review_submissions?
      # Short-circuit logic for admins, who should have the ability
      # to review submissions whether or not they are explicitly
      # granted the approving role in any workflows
      return true if admin?

      # Are there any workflows or entities where this user has the "approving" responsibility
      approving_role = Sipity::Role.find_by(name: Hyrax::RoleRegistry::APPROVING)
      return false unless approving_role

      Hyrax::Workflow::PermissionQuery.scope_processing_agents_for(user: current_user).any? do |agent|
        (agent.workflow_responsibilities.joins(:workflow_role)
            .where('sipity_workflow_roles.role_id' => approving_role.id).any? ||
            agent.entity_specific_responsibilities.joins(:workflow_role).where('sipity_workflow_roles.role_id' => approving_role.id).any?)
      end
    end
end
