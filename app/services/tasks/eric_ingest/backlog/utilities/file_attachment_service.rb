# frozen_string_literal: true
class Tasks::EricIngest::Backlog::Utilities::FileAttachmentService
    SLEEP_INTERVAL = 1
    def initialize(config:, tracker:, log_file_path:, metadata_ingest_result_path:)
        super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
        @existing_ids = load_seen_attachment_ids
        @full_text_path = config['full_text_dir']
    end

    def process_record(record)
        record_id = record.dig('ids', 'work_id')
        filename = "#{record.dig('ids', 'eric_id')}.pdf"
        begin
            file_path = File.join(@full_text_path, filename)
            file_set = attach_pdf_to_work_with_file_path!(record: record,
                                                    file_path: file_path,
                                                    depositor_onyen: config['depositor_onyen'])
            if file_set
                log_attachment_outcome(record,
                                category: category_for_successful_attachment(record),
                                message: 'PDF successfully attached.',
                                file_name: filename)
            end
            # Sleep briefly to avoid overwhelming fedora with rapid requests
            sleep(SLEEP_INTERVAL)
        rescue =>  e
            Rails.logger.error("Error processing record #{record_id}: #{e.message}")
            Rails.logger.error(e.backtrace.join("\n"))
            log_attachment_outcome(record, category: :failed, message: "ERIC File Attachment Error: #{e.message}", file_name: filename)
        end
    end

    def log_attachment_outcome(record, category:, message:, file_name:)
        # Use ERIC ID to track seen records, all ERIC records should have an ERIC ID
        eric_id = record.dig('ids', 'eric_id')
        return if @existing_ids.include?(eric_id) && eric_id.present?
        @existing_ids << eric_id if eric_id.present?

        super(record, category: category, message: message, file_name: file_name)
    end
end
  
