# [hyc-override] Overriding helper in order to use creator_display field for author listings
module Hyrax
  module CitationsBehaviors
    module NameBehavior
      include Hyrax::CitationsBehaviors::CommonBehavior
      include HycHelper

      # return all unique authors with end punctuation removed
      def author_list(work)
        all_authors(work) { |author| clean_end_punctuation(CGI.escapeHTML(author)) }
      end

      # return all unique authors of a work or nil if none
      def all_authors(work, &block)
        if work.creator_display.blank?
          author_vals = []
        else
          if work.creator_display.first.match('index:')
            author_vals = sort_people_by_index(work.creator_display).map { |d| d.split('||').second.titleize }
          else
            author_vals = work.creator_display.map { |d| d.split('|').first.titleize }
          end
        end

        authors = author_vals.uniq.compact
        block_given? ? authors.map(&block) : authors
      end

      def given_name_first(name)
        name = clean_end_punctuation(name)
        return name unless name =~ /,/

        temp_name = name.split(/,\s*/)
        temp_name.last + " " + temp_name.first
      end

      def surname_first(name)
        name = name.join('') if name.is_a? Array
        # make sure we handle "Cher" correctly
        return name if name.include?(',')

        name_segments = name.split(' ')
        given_name = name_segments.first
        surnames = name_segments[1..-1]
        if surnames
          "#{surnames.join(' ')}, #{given_name}"
        else
          given_name
        end
      end

      def abbreviate_name(name)
        abbreviated_name = ''
        name = name.join('') if name.is_a? Array

        # make sure we handle "Cher" correctly
        return name unless name.include?(' ') || name.include?(',')

        name = surname_first(name)
        name_segments = name.split(/,\s*/)
        abbreviated_name << name_segments.first
        abbreviated_name << ", #{name_segments.last.first}" if name_segments[1]
        abbreviated_name << "."
      end
    end
  end
end
