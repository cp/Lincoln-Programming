%w(sinatra active_record open-uri twilio-ruby validates_phone_number).each{|x| require x}

ENV['RACK_ENV'] == 'production' ? db = URI.parse(ENV['DATABASE_URL']) : db = URI.parse('postgres://localhost/lincolnprogramming')

twilio = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_AUTH_TOKEN'])

ActiveRecord::Base.establish_connection(
  :adapter  => 'postgresql',
  :host     => db.host,
  :username => db.user,
  :password => db.password,
  :database => db.path[1..-1],
  :encoding => 'utf8'
)

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
