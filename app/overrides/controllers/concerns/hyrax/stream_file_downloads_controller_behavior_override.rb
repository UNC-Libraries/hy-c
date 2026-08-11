# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/controllers/concerns/hyrax/stream_file_downloads_controller_behavior.rb
Hyrax::StreamFileDownloadsControllerBehavior.module_eval do
  # rubocop:disable Metrics/AbcSize
  def send_range
    _, range = request.headers['HTTP_RANGE'].split('bytes=')
    # [hyc-override] assume client is requesting whole file if no range specified
    range = '0-' if range.nil?
    from, to = range.split('-').map(&:to_i)
    to = file.size - 1 unless to
    length = to - from + 1
    response.headers['Content-Range'] = "bytes #{from}-#{to}/#{file.size}"
    response.headers['Content-Length'] = length.to_s
    self.status = 206
    prepare_file_headers

    if request.head?
      head status
    else
      stream_body file.stream(request.headers['HTTP_RANGE'])
    end
  end
  # rubocop:enable Metrics/AbcSize
end
