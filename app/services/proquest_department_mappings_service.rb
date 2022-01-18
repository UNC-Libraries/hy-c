# app/services/proquest_department_mappings_service.rb
module ProquestDepartmentMappingsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('proquest_departments')

  def self.standard_department_name(proquest_department)
    [authority.find(proquest_department).fetch('term')].flatten
  rescue StandardError
    Rails.logger.warn "ProquestDepartmentMappingsService: cannot find '#{proquest_department}'"
    puts "ProquestDepartmentMappingsService: cannot find '#{proquest_department}'" # for migration log
    nil
  end
end
