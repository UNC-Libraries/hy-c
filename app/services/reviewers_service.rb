# app/services/reviewers_service.rb
module ReviewersService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('reviewers')

  def self.label(id)
    authority.find(id).fetch('term')
  end
end
