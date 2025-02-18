# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/lib/hyrax/role_registry.rb

module Hyrax
  class RoleRegistry
    MANAGING  = 'managing'
    APPROVING = 'approving'
    DEPOSITING = 'depositing'
    # [hyc-override] Added Viewing role
    VIEWING   = 'viewing' 

    # Override the MAGIC_ROLES constant
    MAGIC_ROLES = {
      MANAGING  => 'Grants access to management tasks',
      APPROVING => 'Grants access to approval tasks',
      DEPOSITING => 'Grants access to depositing tasks',
      VIEWING   => 'Grants access to viewing tasks' 
    }.freeze

    # Override initialize to ensure the correct roles are loaded
    def initialize
      @roles = MAGIC_ROLES.dup
    end
  end
end
