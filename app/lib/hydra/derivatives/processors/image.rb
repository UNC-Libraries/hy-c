# [hyc-override] negate images with black backgrounds
require 'mini_magick'

module Hydra::Derivatives::Processors
  class Image < Processor
    class_attribute :timeout

    def process
      timeout ? process_with_timeout : create_resized_image
    end

    def process_with_timeout
      Timeout.timeout(timeout) { create_resized_image }
    rescue Timeout::Error
      raise Hydra::Derivatives::TimeoutError, "Unable to process image derivative\nThe command took longer than #{timeout} seconds to execute"
    end

    protected

    # When resizing images, it is necessary to flatten any layers, otherwise the background
    # may be completely black. This happens especially with PDFs. See #110
    def create_resized_image
      if ImageService.processor == :graphicsmagick
        create_resized_image_with_graphicsmagick
      else
        create_resized_image_with_imagemagick
      end
    end

    def create_resized_image_with_graphicsmagick
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick image resize method')
      create_image do |temp_file|
        if size
          # remove layers and resize using convert instead of mogrify
          MiniMagick::Tool::Convert.new do |cmd|
            cmd << temp_file.path # input
            cmd.flatten
            cmd.resize(size)
            cmd << temp_file.path # output
          end
        end
      end
    end

    def create_resized_image_with_imagemagick
      Rails.logger.info('[ImageProcessor] Using ImageMagick image resize method')
      create_image do |temp_file|
        if size
          temp_file.flatten
          temp_file.resize(size)
        end
      end
    end

    # negating image if background is black
    def create_image
      xfrm = selected_layers(load_image_transformer)
      yield(xfrm) if block_given?
      xfrm.format(directives.fetch(:format))
      xfrm.quality(quality.to_s) if quality

      # check image profile of original file
      if source_data['backgroundColor'] == '#FFFFFFFFFFFF0000'
        Rails.logger.info "\n\n######\nbackground color is black\n######\n\n"
        xfrm.negate
      end

      write_image(xfrm)
    end

    def source_data
      if ImageService.processor == :graphicsmagick
        MiniMagick::Image.open(source_path).details
      else
        MiniMagick::Image.open(source_path).data
      end
    end

    def write_image(xfrm)
      output_io = StringIO.new
      xfrm.write(output_io)
      output_io.rewind
      output_file_service.call(output_io, directives)
    end

    # Override this method if you want a different transformer, or need to load the
    # raw image from a different source (e.g. external file)
    def load_image_transformer
      MiniMagick::Image.open(source_path)
    end

    private

    def size
      directives.fetch(:size, nil)
    end

    def quality
      directives.fetch(:quality, nil)
    end

    def selected_layers(image)
      if image.type =~ /pdf/i
        image.layers[directives.fetch(:layer, 0)]
      elsif directives.fetch(:layer, false)
        image.layers[directives.fetch(:layer)]
      else
        image
      end
    end
  end
end
