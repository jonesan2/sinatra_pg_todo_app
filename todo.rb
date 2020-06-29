require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    !list[:todos].empty? && todos_incomplete(list) == 0
  end
  
  def list_class(list)
    "complete" if list_complete?(list)
  end
  
  def todos_count(list)
    list[:todos].size
  end
  
  def todos_incomplete(list)
    list[:todos].count { |todo| !todo[:completed] }
  end
  
  def sort_lists(lists, &block)
    lists.each do |list|
      block.call(list) if !list_complete?(list)
    end
    
    lists.each do |list|
      block.call(list) if list_complete?(list)
    end
  end
  
  def sort_todos(list, &block)
    list[:todos].each do |todo|
      block.call(todo) if !todo[:completed]
    end
    
    list[:todos].each do |todo|
      block.call(todo) if todo[:completed]
    end
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET   /lists          -> view all lists
# GET   /lists/new      -> new list form
# POST  /lists          -> create new list
# GET   /lists/1        -> view a single list
# GET   /lists/1/edit   -> edit an existing todo list
# POST  /lists/1        -> rename list

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid.
# Return nil if the name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

# Return an error message if the name is invalid.
# Return nil if the name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end

def load_list(id)
  list = session[:lists].find { |list| list[:id] == id } 
  return list if list
  
  session[:error] = "The specified list was not found."
  redirect "/lists"
end

def next_id(items)
  max = items.map { |item| item[:id] }.max || 0
  max + 1
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single todo list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Rename list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Add a new todo item to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error 
    erb :list, layout: :layout
  else
    
    id = next_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo item from a todo list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    #ajax
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Mark a todo item as complete or incomplete
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed
  
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos in the current list as complete
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos are marked completed."
  
  redirect "/lists/#{@list_id}"
end