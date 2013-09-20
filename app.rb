%w(sinatra active_record twilio-ruby validates_phone_number).each{|x| require x}

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/lincolnprogramming')

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

  if member.save!
    twilio.account.messages.create(
      :from => ENV['TWILIO_NUMBER'],
      :to => '+1' + member.phone,
      :body => "Welcome to Lincoln Programming, #{member.name}! We'll alert you here the morning of our next meeting."
    )
    redirect '/'
  end
end
