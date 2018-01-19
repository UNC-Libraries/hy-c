# app/services/departments_service.rb
module DepartmentsService
  @departments_list = YAML.load_file(Rails.root.join('config', 'authorities', 'departments.yml'))

  def self.select_all_options
    Rails.logger.info "\n\n##########\n#{@departments_list}\n##########\n\n"
    Rails.logger.info "\n\n##########\n#{@departments_list['terms'].count}\n##########\n\n"
    results_array = []
    @departments_list['terms'].each do |element|
      Rails.logger.info "\n\n##########\n#{element}\n##########\n\n"
      results_array = [element['term']]
      element['departments'].reject{ |item| item['active'] == false }.map do |dept|
        results_array << [dept['id'], dept['term']]
      end
    end
    results_array
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
