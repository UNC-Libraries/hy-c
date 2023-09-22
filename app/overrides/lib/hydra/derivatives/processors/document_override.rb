# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-derivatives/blob/v3.8.0/lib/hydra/derivatives/processors/document.rb
Hydra::Derivatives::Processors::Document.class_eval do
  # TODO: soffice can only run one command at a time. Right now we manage this by only running one
  # background job at a time; however, if we want to up concurrency we'll need to deal with this

  # Converts the document to the format specified in the directives hash.
  # TODO: file_suffix and options are passed from ShellBasedProcessor.process but are not needed.
  #       A refactor could simplify this.
  def encode_file(_file_suffix, _options = {})
    convert_to_format
  ensure
    FileUtils.rm_f(converted_file)
    # [hyc-override] clean up the parent temp dir
    FileUtils.rmdir(File.dirname(converted_file))
  end

  private
  def convert_to(format)
    # [hyc-override] create temp subdir for output to avoid repeat filename conflicts
    Rails.logger.debug("Converting document to #{format} from source path: #{source_path} to destination file: #{directives[:url]}")

    temp_dir = File.join(Hydra::Derivatives.temp_file_base, Time.now.nsec.to_s)
    FileUtils.mkdir(temp_dir)
    Rails.logger.debug("Temp directory created for derivatives: #{temp_dir}")

    self.class.encode(source_path, format, temp_dir)

    File.join(temp_dir, [File.basename(source_path, '.*'), format].join('.'))
  end
end
