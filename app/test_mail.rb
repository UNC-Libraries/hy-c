require 'net/smtp'

smtp_address = 'localhost'
smtp_port = 25
domain = 'unc.edu'
from_email = 'no-reply@unc.edu'
to_email = 'dcam@ad.unc.edu'

message = <<~MESSAGE_END
  From: Your Name <#{from_email}>
  To: Recipient Name <#{to_email}>
  Subject: SMTP Test Email

  This is a test email sent from a simple Ruby script.
MESSAGE_END

begin
  Net::SMTP.start(smtp_address, smtp_port, domain) do |smtp|
    smtp.send_message(message, from_email, to_email)
  end
  puts "Email sent successfully!"
rescue Exception => e
  puts "Failed to send email: #{e.message}"
end
