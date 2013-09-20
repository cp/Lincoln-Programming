%w(sinatra active_record open-uri).each{|x| require x}

db = (ENV['DATABASE_URL'] || URI.parse('postgres://localhost/lincolnprogramming'))

ActiveRecord::Base.establish_connection(
  :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
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
