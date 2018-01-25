# app/services/proquest_department_mappings_service.rb
module BiomedDepartmentMappingsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('biomed_departments')

  def self.standard_department_name(addresses)
    (addresses.map do |address|
      begin
        authority.find(address).fetch('term')
      rescue
        nil
      end
    end).flatten.compact
  end
end
