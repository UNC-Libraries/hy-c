# In order to configure all image processes correctly, this initializer must be run before any image configuration files (e.g. mini_magick.rb, riiif.rb)
# Flipflop expects this file to live at config/features.rb, rather than config/initializers, so there is a symlink there pointing to this file,
# created by running `ln -rs config/initializers/01_flipflop.rb config/features.rb`
Flipflop.configure do
  feature :read_only,
          default: false,
          description: 'Put the system into read-only mode. Deposits, edits, approvals and anything that makes a change to the data will be disabled.'
  feature :graphicsmagick,
          default: false,
          description: 'Use GraphicsMagick for image processing, including creating derivatives and riiif image processing. In order for this change to affect derivatives, you must also re-start sidekiq.'
end
