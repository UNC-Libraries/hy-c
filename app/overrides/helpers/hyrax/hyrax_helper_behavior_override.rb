# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/helpers/hyrax/hyrax_helper_behavior.rb

Hyrax::HyraxHelperBehavior.class_eval do
      ##
    # @return [Array<String>] the list of all user groups
    def available_user_groups(ability:)
        user_groups = ability.user_groups
        return user_groups if ability.admin?    
        Rails.logger.info "Pasta - Current user groups: #{ability.user_groups}"
        # Excluding "public" and "registered" groups if non admin user
        user_groups.delete("public")
        user_groups.delete("registered")
        user_groups
    end
end