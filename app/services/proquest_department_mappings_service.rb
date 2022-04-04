# app/services/proquest_department_mappings_service.rb
module ProquestDepartmentMappingsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('proquest_departments')

  def self.standard_department_name(proquest_department)
    [authority.find(proquest_department).fetch('term')].flatten
  rescue StandardError
    Rails.logger.warn "ProquestDepartmentMappingsService: cannot find '#{proquest_department}'"
    raise UnknownDepartmentError
  end

  class UnknownDepartmentError < StandardError
    def message
      'Cannot find related department'
    end
  end
end
