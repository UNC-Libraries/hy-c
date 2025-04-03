# frozen_string_literal: true

# This controller has actions for issuing a challenge page for CloudFlare Turnstile product,
# and then redirecting back to desired page.
#
# It also includes logic for configuring a Rails controller filter to enforce
# redirection to these actions. All the logic related to bot detection with turnstile is
# mostly in this file -- with very flexible configuration in class_attributes -- to facilitate
# future extraction to a re-usable gem if desired.
#
# See more local docs at https://sciencehistory.atlassian.net/wiki/spaces/HDC/pages/2645098498/Cloudflare+Turnstile+bot+detection
#
class BotDetectController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:verify_challenge]

  class_attribute :cf_turnstile_sitekey, default: '1x00000000000000000000AA' # a testing key that always passes
  class_attribute :cf_turnstile_secret_key, default: '1x0000000000000000000000000000000AA' # a testing key always passes

  # how long is a challenge pass good for before re-challenge?
  class_attribute :session_passed_good_for, default: 24.hours

  # Executed at the _controller_ filter level, to last minute exempt certain
  # actions from protection.
  class_attribute :allow_exempt, default: ->(controller) { false }

  class_attribute :cf_turnstile_js_url, default: 'https://challenges.cloudflare.com/turnstile/v0/api.js'
  class_attribute :cf_turnstile_validation_url, default:  'https://challenges.cloudflare.com/turnstile/v0/siteverify'
  class_attribute :cf_timeout, default: 3 # max timeout seconds waiting on Cloudfront Turnstile api
  # key stored in Rails session object with change passed confirmed
  class_attribute :session_passed_key, default: 'bot_detection-passed'
  class_attribute :allowed_ip_ranges, default: [
    '152.2.0.0/16', # Campus
    '152.19.0.0/16', # Campus
    '152.23.0.0/16', # Campus
    '152.54.0.0/20', # RENCI
    '172.17.0.0/18', # VPN
    '172.17.57.0/28', # Library-IT VPN group
    '198.85.230.0/23', # Off campus location
    '204.84.8.0/22', # Off campus location
    '204.84.252.0/22', # Off campus location
    '204.85.176.0/20', # Off campus location
    '204.85.192.0/18' # UNC Hospitals
  ]

  # before_action { |controller| BotDetectController.bot_detection_enforce_filter(controller) }
  def self.bot_detection_enforce_filter(controller)
    return if controller.kind_of?(self) ||
      self.allow_exempt.call(controller) ||
      unc_address?(controller.request.remote_ip) ||
      bot_detect_passed_good?(controller.request)

    # Only challenge facet and advanced search queries
    if issue_challenge?(controller)
      # we can only do GET requests right now
      unless controller.request.get?
        Rails.logger.warn("#{self}: Asked to protect request we could not, unprotected: #{controller.request.method} #{controller.request.url}, (#{controller.request.remote_ip}, #{controller.request.user_agent})")
        return
      end

      Rails.logger.info("#{self.name}: Cloudflare Turnstile challenge redirect: (#{controller.request.remote_ip}, #{controller.request.user_agent}): from #{controller.request.url}")

      # Use Rails.application.routes.url_helpers to access the route helper directly
      # This avoids namespace issues that can occur with controller-specific route helpers
      challenge_url = Rails.application.routes.url_helpers.bot_detect_challenge_path(
        dest: controller.request.original_fullpath
      )

      # status code temporary
      controller.redirect_to challenge_url, status: 307
    end
  end

  # Check whether the passed timestamp from the session_passed_key has expired
  def self.time_check(timestamp)
    return false if timestamp.blank?
    Time.now.to_i < timestamp.to_i
  end

  def challenge
  end

  def verify_challenge
    body = {
      secret:  ENV['CF_TURNSTILE_SECRET_KEY'],
      response: params['cf_turnstile_response'],
      remoteip: request.remote_ip
    }

    response = HTTParty.post(self.cf_turnstile_validation_url,  body: body, timeout: self.cf_timeout)
    result = JSON.parse(response.body)
    # Example turnstile responses
    # {"success"=>true, "error-codes"=>[], "challenge_ts"=>"2025-02-26T18:03:55.394Z", "hostname"=>"catalog-qa.lib.unc.edu", "action"=>"", "cdata"=>"", "metadata"=>{"interactive"=>true}}
    # {"success"=>false, "error-codes"=>["invalid-input-response"], "messages"=>[], "metadata"=>{"result_with_testing_key"=>true}}

    if result['success']
      # mark it as successful in session, and record timestamp. They do need a session/cookies
      # to get through the challenge.
      session[self.session_passed_key] = {
        SESSION_DATETIME_KEY: (Time.now + self.session_passed_good_for).to_i,
        SESSION_IP_KEY: request.remote_ip
      }
    end
    Rails.logger.debug("#{self.class.name}: Cloudflare Turnstile validation result (#{request.remote_ip}, #{request.user_agent}): #{result}")

    render json: result
  rescue HTTParty::Error, JSON::ParserError => e
    # probably a http timeout? or something weird.
    Rails.logger.warn("#{self.class.name}: Cloudflare turnstile validation error (#{request.remote_ip}, #{request.user_agent}): #{e}: #{response&.body}")
    render json: {
      success: false,
      http_exception: e
    }
  end

  private

  # Does the session already contain a bot detect pass that is good for this request
  # Tie to IP address to prevent session replay shared among IPs
  def self.bot_detect_passed_good?(request)
    session_data = request.session[self.session_passed_key]
    return false unless session_data && session_data.kind_of?(Hash)

    timestamp = session_data['SESSION_DATETIME_KEY']
    ip = session_data['SESSION_IP_KEY']
    Rails.logger.debug "Session data: Time: #{timestamp}, IP: #{ip}"

    (ip == request.remote_ip) && self.time_check(timestamp)
  end

  # Check if the request IP is within the allowed UNC subnets
  def self.unc_address?(remote_ip_address)
    return true if '127.0.0.1' == remote_ip_address || '::1' == remote_ip_address

    unc_ip_address = false

    self.allowed_ip_ranges.each do |range|
      unc_ip_address = IPAddr.new(range).include? IPAddr.new(remote_ip_address)
      break if unc_ip_address
    end

    unc_ip_address
  end

  def self.issue_challenge?(controller)
    query_parameters = controller.request.query_parameters
    controller.is_a?(Hyrax::StatsController) \
        || (controller.is_a?(Hyrax::DownloadsController) && query_parameters['file'] != 'thumbnail') \
        || query_parameters.key?('f') || query_parameters.key?('f_inclusive') || query_parameters.key?('clause') \
        || query_parameters.key?('range') || query_parameters.key?('page')
  end
end
