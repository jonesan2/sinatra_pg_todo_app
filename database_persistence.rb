require "pg"

class DatabasePersistence
  
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end
  
  def disconnect
    @db.close
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1;"
    result = query(sql, id)
    
    tuple = result.first
    list_id = tuple["id"].to_i
    { id: list_id, name: tuple["name"], todos: all_todos(list_id) }
  end
  
  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)
    
    result.map do |tuple|
      list_id = tuple["id"].to_i
      { id: list_id, name: tuple["name"], todos: all_todos(list_id) }
    end
  end
  
  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name)
  end
  
  def delete_list(id)
    # associated todos will delete automatically in SQL with ON DELETE CASCADE
    sql = "DELETE FROM lists WHERE id = $1;"
    query(sql, id)
  end 
  
  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $2 WHERE id = $1"
    query(sql, id, new_name)
  end
  
  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2);"
    query(sql, list_id, todo_name)
  end
  
  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2;"
    query(sql, list_id, todo_id)
  end
  
  def update_todo(list_id, todo_id, is_completed)
    sql = "UPDATE todos SET complete = $1 WHERE list_id = $2 AND id = $3;"
    query(sql, is_completed, list_id, todo_id)
  end
  
  def mark_all_todos_complete(list_id)
    sql = "UPDATE todos SET complete = 't' WHERE list_id = $1;"
    query(sql, list_id)
  end
  
  private
  
  # This 'query' method is super cool.
  # Allows you to insert a debug statement into all queries
  # the splat operator will convert the params parameter into an empty
  #   array when there are no arguments; therefore, exec_params will
  #   execute just fine because it will still receive an array.
  # It also takes advantage of the logging output method from Sinatra
  #   to improve formatting and control where debugging output is sent.
  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end
  
  def all_todos(list_id)
    sql = "SELECT id, name, complete FROM todos WHERE list_id = $1;"
    
    result = query(sql, list_id)
    result.map do |tuple|
      complete = tuple["complete"] == 't'
      { id: tuple["id"].to_i, name: tuple["name"], completed: complete } 
    end
  end
  
end
