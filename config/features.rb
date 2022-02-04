Flipflop.configure do
  feature :read_only,
          default: false,
          description: "Put the system into read-only mode. Deposits, edits, approvals and anything that makes a change to the data will be disabled."
  feature :graphicsmagick,
          default: false,
          description: 'Use GraphicsMagick for image processing, including creating derivatives and riiif image processing. In order for this change to affect derivatives, you must also re-start sidekiq.'
end
