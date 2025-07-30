# frozen_string_literal: true
module Tasks::PubmedIngest::SharedUtilities::DbType
  PUBMED = 'pubmed'
  PMC = 'pmc'

  ALL = [PUBMED, PMC].freeze

  def self.valid?(val)
    ALL.include?(val)
  end
end
