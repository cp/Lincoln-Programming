%w(sinatra sinatra/flash active_record twilio-ruby validates_phone_number).each{|x| require x}

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/lincolnprogramming')
enable :sessions
TWILIO = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_AUTH_TOKEN'])

class Member < ActiveRecord::Base
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :phone, presence: true, uniqueness: true, phone_number: {:ten_digits => true}
end

get '/' do
  erb :index
end

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

post '/message/new' do # Accept SMS messages through Twilio.
  status 500 unless validate_twilio_request
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
    Member.find_by_phone(from).destroy
    generate_sms_twiml "Your membership has been removed from the database, and you will not recieve any more notifications."
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
    generate_sms_twiml "Hello! Welcome to the Lincoln Programming Club. Read more and sign up at lincolnprogramming.com"
  end

end

def send_blast(message)
  # I really wish you could just send Twilio an array.
  Member.where('phone IS NOT NULL').each do |member|
    TWILIO.account.messages.create(
      from: ENV['TWILIO_NUMBER'],
      to: member.phone,
      body: message
    )
  end
end

def generate_sms_twiml(text)
  Twilio::TwiML::Response.new do |r|
    r.Sms text
  end.text
end

def validate_twilio_request
  return true unless ENV['RACK_ENV'] == 'production'
  validator = Twilio::Util::RequestValidator.new(ENV['TWILIO_AUTH_TOKEN'])
  validator.validate(request.url, params, request.env['HTTP_X_TWILIO_SIGNATURE'])
end
