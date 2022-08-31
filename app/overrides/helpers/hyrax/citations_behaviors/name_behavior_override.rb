# frozen_string_literal: true
# [hyc-override] Overriding helper in order to use creator_display field for author listings
# https://github.com/samvera/hyrax/blob/v2.9.6/app/helpers/hyrax/citations_behaviors/name_behavior.rb
# There's a test for this helper in the Chicago Formatter tests
Hyrax::CitationsBehaviors::NameBehavior.module_eval do
  # return all unique authors of a work or nil if none
  def all_authors(work, &block)
    author_vals = if work.creator_display.blank?
                    []
                  else
                    if work.creator_display.first.match('index:')
                      sort_people_by_index(work.creator_display).map { |d| d.split('||').second.titleize }
                    else
                      work.creator_display.map { |d| d.split('|').first.titleize }
                    end
                  end

    authors = author_vals.uniq.compact
    block_given? ? authors.map(&block) : authors
  end
end
