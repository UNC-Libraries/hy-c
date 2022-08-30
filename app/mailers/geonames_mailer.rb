class GeonamesMailer < ActionMailer::Base
  def send_mail(e)
    mail(to: ENV['EMAIL_GEONAMES_ERRORS_ADDRESS'], subject: 'Unable to index geonames uri to human readable text') do |format|
      format.text { render plain: e.message }
    end
  end
end
