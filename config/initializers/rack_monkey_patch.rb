# Monkey patch `stringify_keys` to make rack 2.1.1 compatible with Sidekiq UI Admin panel.
# Should be removed when 2.1.2 is released.
# https://github.com/rack/rack/pull/1428
module Rack
  module Session
    module Abstract
      class SessionHash
        private

        def stringify_keys(other)
          other.to_hash.transform_keys(&:to_s)
        end
      end
    end
  end
end
