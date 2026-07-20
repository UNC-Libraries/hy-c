# frozen_string_literal: true

Flipflop.configure do
  feature :challenge_downloads,
          default: false,
          description: 'Enable Cloudflare Turnstile checks for file downloads.'
end
