# [hyc-override] Overriding helper in order to use date_issued, if present, for publication date
module Hyrax
  module CitationsBehaviors
    module PublicationBehavior
      include Hyrax::CitationsBehaviors::CommonBehavior
      def setup_pub_date(work)
        if work.respond_to?(:date_issued)
          file_date = work.date_issued
          first_date = file_date.respond_to?(:first) ? file_date.first : file_date
        else
          first_date = ''
        end

        if first_date.present?
          first_date = CGI.escapeHTML(first_date)
          date_value = /\d{4}/.match(first_date)
          return nil if date_value.nil?
        end
        clean_end_punctuation(date_value[0]) if date_value
      end

      # @param [Hyrax::WorkShowPresenter] work_presenter
      def setup_pub_place(work_presenter)
        work_presenter.based_near_label&.first
      end

      def setup_pub_publisher(work)
        work.publisher&.first
      end

      def setup_pub_info(work, include_date = false)
        pub_info = ""
        if (place = setup_pub_place(work))
          pub_info << CGI.escapeHTML(place)
        end
        if (publisher = setup_pub_publisher(work))
          pub_info << ": " << CGI.escapeHTML(publisher)
        end

        pub_date = include_date ? setup_pub_date(work) : nil
        pub_info << ", " << pub_date unless pub_date.nil?

        pub_info.strip!
        pub_info.blank? ? nil : pub_info
      end
    end
  end
end
