# frozen_string_literal: true
# [hyc-override] Uncomment line in roles_for_agent
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/forms/hyrax/forms/permission_template_form.rb
Hyrax::Forms::PermissionTemplateForm.class_eval do
    def roles_for_agent
        roles = []
        grants_as_collection.each do |grant|
          case grant[:access]
          when Hyrax::PermissionTemplateAccess::DEPOSIT
            roles << Sipity::Role.find_by(name: Hyrax::RoleRegistry::DEPOSITING)
          when Hyrax::PermissionTemplateAccess::MANAGE
            roles += Sipity::Role.where(name: Hyrax::RoleRegistry.new.role_names)
            when Hyrax::PermissionTemplateAccess::VIEW
            roles << Sipity::Role.find_by(name: Hyrax::RoleRegistry::VIEWING)
          end
        end
        roles.uniq
      end
  end
  