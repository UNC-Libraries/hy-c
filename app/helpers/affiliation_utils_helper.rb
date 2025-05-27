# frozen_string_literal: true
module AffiliationUtilsHelper
  # Matches common variations: "UNC Chapel Hill", "UNC-Chapel Hill", full university name, and abbreviations
  # Handles missing prepositions (e.g., "at", "of") and varied spacing/hyphenation
  # Case-insensitive and whitespace-tolerant
  UNC_AFFILIATION_REGEX = /
    \bUNC(?:[-\s]?Chapel\s*Hill)?\b |
    \bUniversity\s+of\s+(North|N)\s+Carolina(?:[-,\s]+(?:at\s+)?)?Chapel\s*Hill\b |
    \bUniv(?:ersity)?\s+(?:of\s+)?N(?:orth)?\s+Carolina(?:[-,\s]+(?:at\s+)?)?Chapel\s*Hill\b
    /ix.freeze

  # Returns true if the given affiliation string likely refers to UNC-Chapel Hill
  def self.unc_affiliation?(affiliation_text)
    # Convert regex match to strict boolean
    !!(affiliation_text.to_s =~ UNC_AFFILIATION_REGEX)
  end
end
