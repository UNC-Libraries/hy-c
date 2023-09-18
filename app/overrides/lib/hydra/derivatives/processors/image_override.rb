# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-derivatives/blob/v3.8.0/lib/hydra/derivatives/processors/image.rb
Hydra::Derivatives::Processors::Image.class_eval do
  protected
    # [hyc-override] Updated to work with graphicsmagick instead of imagemagick
    def create_resized_image
      create_resized_image_with_graphicsmagick
    end

    def create_resized_image_with_graphicsmagick
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

    def create_image
      xfrm = selected_layers(load_image_transformer)
      yield(xfrm) if block_given?
      xfrm.format(directives.fetch(:format))
      xfrm.quality(quality.to_s) if quality

      # [hyc-override] check image profile of original file, and negate if background is black
      if source_data['backgroundColor'] == '#FFFFFFFFFFFF0000'
        Rails.logger.info "\n\n######\nbackground color is black\n######\n\n"
        xfrm.negate
      end

      write_image(xfrm)
    end

    # [hyc-override] New method which returns the details of the image being processed
    def source_data
      MiniMagick::Image.open(source_path).details
    end
end