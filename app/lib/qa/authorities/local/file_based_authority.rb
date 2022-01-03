# [hyc-override] Overriding to allow custom keys for Questioning Authority vocabularies
module Qa::Authorities
  class Local::FileBasedAuthority < Base
    attr_reader :subauthority
    def initialize(subauthority)
      @subauthority = subauthority
    end

    def search(q)
      r = q.blank? ? [] : terms.select { |term| /\b#{q.downcase}/.match(term[:term].downcase) }
      r.map do |res|
        term_list(res, false).with_indifferent_access
      end
    end

    def all
      terms.map do |res|
        term_list(res).with_indifferent_access
      end
    end

    def find(id)
      # If an id includes https, translate it to http
      id["https"] = "http" if id.include?("https")
      terms.find { |term| term[:id] == id } || {}
    end

    private

    def terms
      subauthority_hash = YAML.load(File.read(subauthority_filename)) # rubocop:disable Security/YAMLLoad # TODO: Explore how to change this to safe_load.  Many tests fail when making this change.
      terms = subauthority_hash.with_indifferent_access.fetch(:terms, [])
      normalize_terms(terms)
    end

    # [hyc-override] Overriding to allow custom keys for Questioning Authority vocabularies
    def term_list(field, show_all_fields = true)
      returned_values = {}
      keys = field.keys

      keys.each do |key|
        key_sym = key.to_sym

        if key_sym == :term
          returned_values[:label] = field[:term]
        else
          returned_values[key_sym] = field[key_sym]
        end
      end

      if show_all_fields
        returned_values[:active] = field.fetch(:active, true)
      end

      returned_values
    end

    def subauthority_filename
      File.join(Local.subauthorities_path, "#{subauthority}.yml")
    end

    def normalize_terms(terms)
      terms.map do |term|
        if term.is_a? String
          { id: term, term: term }.with_indifferent_access
        else
          term[:id] ||= term[:term]
          term
        end
      end
    end
  end
end
