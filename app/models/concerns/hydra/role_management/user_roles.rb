# frozen_string_literal: true
module Hydra
  module RoleManagement
    # Module offering methods for user behavior managing roles and groups
    module UserRoles
      extend ActiveSupport::Concern

      included do
        has_and_belongs_to_many :roles
      end

      def groups
        g = roles.map(&:name)
        g += ['registered'] unless new_record? || guest?
        g
      end

      def guest?
        if defined?(DeviseGuests)
          self[:guest]
        else
          false
        end
      end

      def admin?
        roles.where(name: 'admin').exists?
      end
    end
  end
end