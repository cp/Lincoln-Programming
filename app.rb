%w(sinatra active_record open-uri).each{|x| require x}

db = (URI.parse(ENV['DATABASE_URL']) || URI.parse('postgres://localhost/lincolnprogramming'))

ActiveRecord::Base.establish_connection(
  :adapter  => 'postgresql',
  :host     => db.host,
  :username => db.user,
  :password => db.password,
  :database => db.path[1..-1],
  :encoding => 'utf8'
)

class Member < ActiveRecord::Base
end

get '/' do
  erb :index
end
