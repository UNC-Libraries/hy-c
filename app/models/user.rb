# [hyc-override] Overriding user model to allow shibboleth integration
# [hyc-override]Overriding hyrax default rewriting email addresses
class User < ApplicationRecord
  # Connects this user object to Hydra behaviors.
  include Hydra::User
  # Connects this user object to Role-management behaviors.
  include Hydra::RoleManagement::UserRoles


  # Connects this user object to Hyrax behaviors.
  include Hyrax::User
  include Hyrax::UserUsageStats



  if Blacklight::Utils.needs_attr_accessible?
    attr_accessible :email, :password, :password_confirmation
  end
  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise_modules = [:omniauthable, :rememberable, :trackable, omniauth_providers: [:shibboleth], authentication_keys: [:uid]]
  devise_modules.prepend(:database_authenticatable, :registerable) if AuthConfig.use_database_auth?
  devise(*devise_modules)

  # When a user authenticates via shibboleth, find their User object or make
  # a new one. Populate it with data we get from shibboleth.
  # @param [OmniAuth::AuthHash] auth
  def self.from_omniauth(auth)
    # Rails.logger.debug "auth = #{auth.inspect}"
    # Uncomment the debugger above to capture what a shib auth object looks like for testing
    # default to onyen@ad.unc.edu
    email = "#{auth.info.uid}@ad.unc.edu"
    user = where(uid: auth.info.uid).first_or_create(provider: auth.provider, email: email)
    user.display_name = auth.info.uid
    user.save
    user
  end

  # [hyc-override] Overriding hyrax default of changing email "." characters to "-dot-"
  def to_param
    user_key
  end

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account.
  def to_s
    email
  end

  # Mailboxer (the notification system) needs the User object to respond to this method
  # in order to send emails
  def mailboxer_email(_object)
    email
  end
end

# Override a Hyrax class that expects to create system users with passwords.
# Since in production we're using shibboleth, and this removes the password
# methods from the User model, we need to override it.
module Hyrax::User
  module ClassMethods
    def find_or_create_system_user(user_key)
      user = ::User.find_or_create_by(uid: user_key)
      user.display_name = user_key
      user.email = "#{user_key}@ad.unc.edu"
      user.password = ('a'..'z').to_a.shuffle(random: Random.new).join if AuthConfig.use_database_auth?
      user.save
      user
    end
  end
end
