%w(sinatra sinatra/flash active_record twilio-ruby validates_phone_number).each{|x| require x}

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/lincolnprogramming')
enable :sessions
twilio = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_AUTH_TOKEN'])

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
    twilio.account.messages.create(
      :from => ENV['TWILIO_NUMBER'],
      :to => '+1' + member.phone,
      :body => "Welcome to Lincoln Programming, #{member.name}! We'll alert you here the morning of our next meeting."
    )
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
        Twilio::TwiML::Response.new do |r|
          r.Sms "Your phone number was successfully added"
        end.text
      end
    else
      Twilio::TwiML::Response.new do |r|
        r.Sms "We could not find your account. Creat one at lincolnprogramming.com"
      end.text
    end
  elsif body == 'unsubscribe'
    Member.find_by_phone(from).destroy
    Twilio::TwiML::Response.new do |r|
      r.Sms "Your membership has been removed from the database, and you will not recieve any more notifications."
    end.text
  else
    Twilio::TwiML::Response.new do |r|
      r.Sms "Hello! Welcome to the Lincoln Programming Club. Read more and sign up at lincolnprogramming.com"
    end.text
  end

end

def validate_twilio_request
  return true unless ENV['RACK_ENV'] == 'production'
  validator = Twilio::Util::RequestValidator.new(ENV['TWILIO_AUTH_TOKEN'])
  validator.validate(request.url, params, request.env['HTTP_X_TWILIO_SIGNATURE'])
end
