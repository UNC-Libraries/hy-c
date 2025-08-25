# frozen_string_literal: true
module AffiliationUtilsHelper
  # Matches common variations: "UNC Chapel Hill", "UNC-Chapel Hill", full university name, and abbreviations
  # Handles missing prepositions (e.g., "at", "of") and varied spacing/hyphenation
  # Case-insensitive and whitespace-tolerant
  UNC_AFFILIATION_REGEX = /
  \bUNC(?:[-\s]?Chapel\s*Hill)?\b |                # "UNC Chapel Hill" or "UNC-Chapel Hill"
  \bUNCCH\b |                                     # "UNCCH"
  \bUniversity\s+of\s+(North|N)\s+Carolina        # "University of North Carolina"
    (?:[-,\s]+(?:at\s+)?)?Chapel\s*Hill\b |       # Optional: ", at", " at", " Chapel Hill"
  \bUniv(?:ersity)?\s+(?:of\s+)?N(?:orth)?\s+     # "Univ of N Carolina at Chapel Hill"
    Carolina(?:[-,\s]+(?:at\s+)?)?Chapel\s*Hill\b
/ix.freeze

  UNC_AFFILIATION_TERMS = [
     # Core names
     'University of North Carolina at Chapel Hill',
     'University of North Carolina Chapel Hill',
     'UNC Chapel Hill',
     'UNC-Chapel Hill',
     'UNCCH',

     # Health system / hospitals
     'UNC Health',
     'UNC Health Care',
     'UNC Hospitals',

     # Major UNC-CH units that often appear as affiliation strings
     'UNC School of Medicine',
     'School of Medicine, University of North Carolina at Chapel Hill',
     'UNC Eshelman School of Pharmacy',
     'Eshelman School of Pharmacy, University of North Carolina at Chapel Hill',
     'UNC Gillings School of Global Public Health',
     'Gillings School of Global Public Health, University of North Carolina at Chapel Hill',
     'UNC Lineberger Comprehensive Cancer Center',
     'Lineberger Comprehensive Cancer Center, University of North Carolina at Chapel Hill',
     'Cecil G. Sheps Center for Health Services Research',
     'Carolina Population Center',
     'Odum Institute for Research in Social Science',
     'UNC Kenan-Flagler Business School'
   ].freeze

  # Returns true if the given affiliation string likely refers to UNC-Chapel Hill
  def self.is_unc_affiliation?(affiliation_text)
    return false if affiliation_text.nil? || affiliation_text.strip.empty?
    # Convert regex match to strict boolean
    !!(affiliation_text.to_s =~ UNC_AFFILIATION_REGEX)
  end
end
