# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/helpers/hyrax/hyrax_helper_behavior.rb

Hyrax::HyraxHelperBehavior.class_eval do
      ##
    # @return [Array<String>] the list of all user groups
    def available_user_groups(ability:)
        var = ::User.group_service.role_names
        Rails.logger.info "Pasta - Current user groups: #{ability.user_groups}"
        return var if ability.admin?    
        group = ability.user_groups
        # group << "registered"
        # group << "public"
        # Excluding "public" and "registered" groups if non admin user
        group.delete("public")
        group.delete("registered")
        group
    end
end