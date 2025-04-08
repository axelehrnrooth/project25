require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'


DB = SQLite3::Database.new "db/databas.db"
DB.results_as_hash = true

enable :sessions

before do
  session["password"] ||= "abc123"
  session["username"] ||= "admin"
  session["notes"] ||= []
  session["logged_in"] ||= false
  session[:rankings] ||= []
end

get('/') do
  slim(:index)
end

get('/login') do
  slim(:'user/login')
end

get('/dokumentation') do
  slim(:'dokumentation')
end

post('/login') do
  username = params[:username]
  password = params[:password]

  user = DB.execute("SELECT * FROM users WHERE username = ?", username).first

  if user && BCrypt::Password.new(user["password_digest"]) == password
    session[:logged_in] = true
    session[:username] = username
    redirect('/notes')
  else
    session[:logged_in] = false
    redirect('/error')
  end
end

post('/logout') do
  session.clear  
  redirect('/login')  
end

get('/error') do
  slim(:'error')
end

get('/notes/new') do
  if session["logged_in"]
    slim(:'notes/new')
  else
    redirect('/error')
  end
end

get('/notes') do
  if session["logged_in"]
    user = DB.execute("SELECT * FROM users WHERE username = ?", session[:username]).first
    @notes = DB.execute("SELECT * FROM notes WHERE user_id = ?", user["id"])
    slim(:'notes/show')
  else
    redirect('/error')
  end
end

post('/notes/create') do
  title = params["title"]
  content = params["ny_note"]
  author = params["author"]

  user = DB.execute("SELECT * FROM users WHERE username = ?", session[:username]).first
  DB.execute("INSERT INTO notes (title, content, author, user_id) VALUES (?, ?, ?, ?)", [title, content, author, user["id"]])

  redirect('/notes')
end

post('/notes/clear') do
  user = DB.execute("SELECT * FROM users WHERE username = ?", session[:username]).first
  DB.execute("DELETE FROM notes WHERE user_id = ?", user["id"])
  redirect('/notes')
end

post('/notes/delete') do
  note_id = params["id"].to_i
  DB.execute("DELETE FROM notes WHERE id = ?", note_id)
  redirect('/notes')
end

get('/user/edit') do 
  slim(:"user/edit")
end

post('/user/update') do
  new_username = params["username"]
  new_password = params["password"]
  current_username = session[:username]

  user = DB.execute("SELECT * FROM users WHERE username = ?", current_username).first

  if user
    new_password_digest = BCrypt::Password.create(new_password)
    DB.execute("UPDATE users SET username = ?, password_digest = ? WHERE id = ?", [new_username, new_password_digest, user["id"]])
    session[:username] = new_username
    redirect('/notes')
  else
    redirect('/error')
  end
end

get '/ranking' do
  slim :ranking
end

post '/save_ranking' do
  category = params[:category]

  # Tar bort nummerprefix från början av varje input
  rankings = params[:rankings].map do |r|
    r = r.to_s.strip
    r.sub(/^\d+[\.\:\-\s]\s*/, '') # tar bort "1. ", "2- ", "3: ", "4 ", etc
  end

  # Tar bort tomma fält
  rankings.reject! { |r| r.empty? }

  session[:rankings] << { category: category, scores: rankings }

  redirect '/ranking'
end

post '/ranking/delete' do
  index = params[:index].to_i
  session[:rankings].delete_at(index) if session[:rankings] && index >= 0
  redirect '/ranking'
end
