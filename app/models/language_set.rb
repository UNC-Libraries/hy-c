class LanguageSet < ::BlacklightOaiProvider::Set
  def description
    if @spec
      'This set includes files in the '+@spec.split(':').last.capitalize+' language.'
    else
      'No description available.'
    end
  end
end