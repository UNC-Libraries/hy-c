# frozen_string_literal: true
require 'erb'

# @TODO This patch can be removed when we can update to sprockets 4 or later.
# =============================================================================
# ERB Compatibility Patch for Sprockets 3 on Modern Ruby Versions
# =============================================================================
# WHY THIS IS NEEDED:
# Hyrax is pinned to sprockets 3.7.2, which uses positional arguments: `ERB.new(str, safe_level, trim_mode)`.
#
# Rails 7.2.3.1 and later require keyword arguments, causing an `ArgumentError: wrong number of
# arguments (given 3, expected 1)` when compiling assets.
#
# WHAT THIS OVERRIDE DOES:
# This monkey-patch intercepts calls to `ERB.new`. It checks how the arguments
# are structured. If it detects the legacy positional signatures coming from
# Sprockets 3, it dynamically reformats them into modern keyword arguments
# (`trim_mode:` and `eoutvar:`) before passing them to Ruby's native constructor.
# It preserves normal behavior if modern keyword arguments are used.
# =============================================================================

class ERB
  class << self
    alias_method :original_new, :new

    def new(template_source, legacy_safe_level = nil, legacy_trim_mode = nil, legacy_eoutvar = '_erbout')
      # Detect if modern keyword arguments were passed instead of legacy positional arguments
      if legacy_safe_level.is_a?(Hash)
        keyword_arguments = legacy_safe_level
        original_new(template_source, **keyword_arguments)
      else
        # Safely convert legacy Sprockets 3 positional arguments into modern Ruby keywords
        original_new(
          template_source,
          trim_mode: legacy_trim_mode,
          eoutvar: legacy_eoutvar
        )
      end
    end
  end
end
