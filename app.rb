%w(sinatra sinatra/flash active_record twilio-ruby validates_phone_number dotenv typhoeus).each{|x| require x}

Dotenv.load! unless ENV['RACK_ENV'] == 'production'

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/lincolnprogramming')
enable :sessions
TWILIO = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_AUTH_TOKEN'])

class Member < ActiveRecord::Base
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :phone, presence: true, uniqueness: true, phone_number: {:ten_digits => true}

  # Mark the user as unsubscribed. Here's to never deleting data!
  def unsubscribe!
    self.update_attributes(unsubscribed: true)
  end
end

get '/' do
  erb :index
end

# This endpoint is reserved for the online form.
post '/member/new' do
  member = Member.new(name: params[:name], phone: params[:phone], email: params[:email])

  if member.save
    TWILIO.account.messages.create(
      from: ENV['TWILIO_NUMBER'],
      to: '+1' + member.phone,
      body: "Welcome to Lincoln Programming, #{member.name}! We'll alert you here the morning of our next meeting."
    )
    flash[:message] = "Welcome, #{member.name}! You should recieve a confirmation text message shortly."
    redirect '/'
  else
    flash[:errors] = member.errors.full_messages.join(', ').downcase
    redirect '/'
  end
end

# This is the endpoint hit whenever someone messages our service.
post '/message/new' do # Accept SMS messages through Twilio.
  status 400 unless validate_twilio_request
  body = params['Body']
  from = params['From'][2..-1]

  # Since we don't yet have members' phone numbers,
  # this will allow them to text in their email, and
  # add their phone number to their account.
  if body.length > 5 && body.split('').include?('@')
    if member = Member.find_by_email(body)
      member.phone = from
      if member.save(validate: false)
        generate_sms_twiml "Your phone number was successfully added."
      end
    elsif member = Member.new(email: body, phone: from)
      if member.save(validate: false)
        generate_sms_twiml "We couldn't find a membership with this email, so we went ahead and created a new one. Welcome!"
      end
    end
  elsif body == 'unsubscribe'
    Member.find_by_phone(from).unsubscribe!
    generate_sms_twiml "You have been unsubscribed, and you will not recieve any more notifications at this number."
  elsif body.split[0] == 'blast'
    if member = Member.find_by_phone(from)
      if member.is_admin
        send_blast body.split[1..-1].join(' ')
        generate_sms_twiml "Sent!"
      else
        generate_sms_twiml "You are not an admin, and do not have permission to do this."
      end
    end
  else
    alert_admins(body, from)
    generate_sms_twiml "Hello! Welcome to the Lincoln Programming Club. Read more and sign up at lincolnprogramming.com"
  end

end

# This sends a message to all subscribed users.
#
# @param [String] message to send to users.
def send_blast(message)
  # Sending them concurrently like a boss.
  hydra = Typhoeus::Hydra.new
  Member.where('phone IS NOT NULL').where(unsubscribed: false).each do |member|
    hydra.queue(Typhoeus::Request.new(
      "https://api.twilio.com/2010-04-01/Accounts/#{ENV['TWILIO_SID']}/Messages", 
      method: :post,
      body: { "To" => member.phone, "From" => ENV['TWILIO_NUMBER'], "Body" => message },
      userpwd: "#{ENV['TWILIO_SID']}:#{ENV['TWILIO_AUTH_TOKEN']}"
    ))
  end
  hydra.run
end

# Simply forward the message on to admins
# in case they're curious, or if someone
# has something important to say.
#
# @param [String] message to send to admins.
# @param [String] number incoming message was sent from.
def alert_admins(message, number)
  alert = "New message from #{number}: '#{message}'"

  Member.where('phone IS NOT NULL').where(is_admin: true).each do |admin|
    hydra.queue(Typhoeus::Request.new(
      "https://api.twilio.com/2010-04-01/Accounts/#{ENV['TWILIO_SID']}/Messages", 
      method: :post,
      body: { "To" => admin.phone, "From" => ENV['TWILIO_NUMBER'], "Body" => alert },
      userpwd: "#{ENV['TWILIO_SID']}:#{ENV['TWILIO_AUTH_TOKEN']}"
    ))
  end
  hydra.run
end

# Generates valid "TWIML" given some text.
#
# @param [String] text
def generate_sms_twiml(text)
  Twilio::TwiML::Response.new do |r|
    r.Sms text
  end.text
end

# Ensures that the given request is valid. Only applies to production.
#
# @return [Boolean] whether or not the request is valid.
def validate_twilio_request
  return true unless ENV['RACK_ENV'] == 'production'
  validator = Twilio::Util::RequestValidator.new(ENV['TWILIO_AUTH_TOKEN'])
  validator.validate(request.url, params, request.env['HTTP_X_TWILIO_SIGNATURE'])
end
