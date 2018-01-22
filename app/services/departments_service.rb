# app/services/departments_service.rb
module DepartmentsService
  @departments_list = YAML.load_file(Rails.root.join('config', 'authorities', 'departments.yml'))

  def self.select_all_options
    select_options_array = []
    @departments_list['terms'].each do |element|
      school_array = [element['term']]
      department_array = []
      element['departments'].reject{ |item| item['active'] == false }.map do |dept|
        department_array << dept['id']
      end
      school_array << department_array
      select_options_array << school_array
    end
    select_options_array
  end

  def self.label(id)
    authority.find(id).fetch('term')
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank? || active?(value)
      html_options[:class] << ' force-select'
      render_options += [[label(value), value]]
    end
    [render_options, html_options]
  end
end
