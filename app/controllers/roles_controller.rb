class RolesController < ApplicationController
  include Hydra::RoleManagement::RolesBehavior

  layout 'hyrax/dashboard'
end
