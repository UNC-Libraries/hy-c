class CdrListSet < ::BlacklightOaiProvider::SolrSet
  def description
    if label && value
      "This set includes works in the #{value} #{label}."
    else
      'No description available.'
    end
  end
end
