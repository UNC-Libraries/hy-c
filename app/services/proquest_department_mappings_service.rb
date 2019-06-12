# app/services/proquest_department_mappings_service.rb
module ProquestDepartmentMappingsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('proquest_departments')

  def self.standard_department_name(proquest_department)
    begin
      [authority.find(proquest_department).fetch('term')].flatten
    rescue
      Rails.logger.warn "ProquestDepartmentMappingsService: cannot find '#{id}'"
      puts "ProquestDepartmentMappingsService: cannot find '#{id}'" # for migration log
      nil
    end
  end
end
