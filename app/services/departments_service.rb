# app/services/departments_service.rb
module DepartmentsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('departments')

  def self.select_all_options
    authority.all.reject{ |item| item['active'] == false }.map do |element|
      [element[:id], element[:id]]
    end
  end

  def self.identifier(term)
    begin
      authority.all.reject{ |item| item['active'] == false }.select { |department| department['label'] == term }.first['id']
    rescue
      nil
    end
  end

  def self.label(id)
    begin
      active = authority.find(id).fetch('active')
      label = authority.find(id).fetch('term')
      new_label = ''
      while !active && new_label != label
        if !new_label.blank?
          label = new_label
        end
        active = authority.find(label).fetch('active')
        new_label = authority.find(label).fetch('term')
      end
      label
    rescue
      Rails.logger.warn "DepartmentsService: cannot find '#{id}'"
      puts "DepartmentsService: cannot find '#{id}'" # for migration log
      nil
    end
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank?
      html_options[:class] << ' force-select'
      # Add the current value to the options if it is not already present
      value_index = render_options.index { |opt| opt[0] == value }
      if value_index == nil
        render_options += [[value, value]]
      end
    end
    [render_options, html_options]
  end
end
