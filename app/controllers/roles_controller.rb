class RolesController < ApplicationController
  include Hydra::RoleManagement::RolesBehavior

  layout 'dashboard'
end
