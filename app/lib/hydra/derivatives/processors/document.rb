# [hyc-override] create and clean up temp files
module Hydra::Derivatives::Processors
  class Document < Processor
    include ShellBasedProcessor

    def self.encode(path, format, outdir)
      Rails.logger.debug("Encoding with path: #{path}, format: #{format}, outdir: #{outdir}")
      command = "#{Hydra::Derivatives.libreoffice_path} --invisible --headless --convert-to #{format} --outdir #{outdir} #{Shellwords.escape(path)}"
      Rails.logger.debug("Encoding using command #{command}")
      execute(command)
    end

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

    # For jpeg files, a pdf is created from the original source and then passed to the Image processor class
    # so we can get a better conversion with resizing options. Otherwise, the ::encode method is used.
    def convert_to_format
      if directives.fetch(:format) == 'jpg'
        Hydra::Derivatives::Processors::Image.new(converted_file, directives).process
      else
        output_file_service.call(File.read(converted_file), directives)
      end
    end

    def converted_file
      @converted_file ||= if directives.fetch(:format) == 'jpg'
                            convert_to('pdf')
                          else
                            convert_to(directives.fetch(:format))
                          end
    end

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
end
