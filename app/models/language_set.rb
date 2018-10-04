class LanguageSet < ::BlacklightOaiProvider::SolrSet
  def description
    if label && value
      "This set includes files in the #{value.capitalize} language."
    else
      'No description available.'
    end
  end
end