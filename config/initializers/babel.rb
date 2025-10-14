require 'babel/transpiler'

Rails.application.config.assets.configure do |env|
  if defined?(Babel::Transpiler)
    babel_processor = proc do |input|
      begin
        # Generate the correct AMD module ID from the file path
        # Extract the path relative to javascripts directory
        relative_path = input[:filename].gsub(%r{.*/app/assets/javascripts/}, '')
        module_id = relative_path.gsub(/\.es6$/, '')

        result = Babel::Transpiler.transform(input[:data], {
          'modules' => 'amd',
          'stage' => 0,
          'moduleId' => module_id
        })
        { data: result['code'] }
      rescue => e
        puts("Babel ERROR: #{e.message}")
        { data: input[:data] }
      end
    end

    # Override the ES6 transformer
    env.register_transformer 'text/ecmascript-6', 'application/javascript', babel_processor
  else
    puts("###Babel Initializer: Babel not available")
  end
end