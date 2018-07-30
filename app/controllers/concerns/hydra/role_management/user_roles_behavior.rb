# [hyc-override] Overriding user roles controller to create users before adding to groups
module Hydra
  module RoleManagement
    module UserRolesBehavior
      extend ActiveSupport::Concern

      included do
        load_and_authorize_resource :role
      end

      def create
        authorize! :add_user, @role
        u = find_user
        if u
          u.roles << @role
          u.save!
          redirect_to role_management.role_path(@role)
        else
          user = where(provider: 'shibboleth', uid: params[:user_key], email: "#{params[:user_key]}@email.unc.edu").first_or_create
          user.display_name = params[:user_key]
          user.roles << @role
          user.save!
          redirect_to role_management.role_path(@role)
        end
      end

      def destroy
        authorize! :remove_user, @role
        @role.users.delete(::User.find(params[:id]))
        redirect_to role_management.role_path(@role)
      end

      protected

      def find_user
        ::User.send("find_by_#{find_column}".to_sym, params[:user_key])
      end

      def find_column
        Devise.authentication_keys.first
      end
    end
  end
end
