require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "todos")
    end
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    # @session[:lists].find { |l| l[:id] == id }
    sql = <<~SQL
      SELECT * FROM lists
      WHERE id = $1;
    SQL
    result = query(sql, id)
    tuple = result.first

    list_id = tuple["id"].to_i
    todos = find_todos_for_list(list_id)
    {id: list_id, name: tuple["name"], todos: todos }
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
        FROM lists
        LEFT JOIN todos on todos.list_id = lists.id
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL

    result = query(sql)

    result.map do |tuple|
      { id: tuple["id"].to_i,
        name: tuple["name"],
        todos_count: tuple["todos_count"].to_i,
        todos_remaining_count: tuple["todos_remaining_count"].to_i
      }
    end

  end

  def create_new_list(list_name)
    sql = <<~SQL
      INSERT INTO lists (name)
        VALUES ($1);
    SQL
    query(sql, list_name)
  end

  def delete_list(id)
    delete_todos_sql = <<~SQL
      DELETE FROM todos
      WHERE list_id = $1;
    SQL
    delete_lists_sql = <<~SQL
      DELETE FROM lists
      WHERE id = $1;
    SQL
    query(delete_todos_sql, id)
    query(delete_lists_sql, id)
  end

  def update_list_name(id, new_name)
    sql = <<~SQL
      UPDATE lists
      SET name = $1
      WHERE id = $2;
    SQL

    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = <<~SQL
      INSERT INTO todos(list_id, name)
      VALUES($1, $2);
    SQL
    query(sql, list_id, todo_name)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = <<~SQL
      DELETE FROM todos
      WHERE id = $1
      AND   list_id = $2;
    SQL
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = <<~SQL
      UPDATE todos
      SET completed = $1
      WHERE id = $2 AND list_id = $3
    SQL
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = <<~SQL
      UPDATE todos
      SET completed = true
      WHERE list_id = $1
    SQL
    query(sql, list_id)
  end

  private
  def find_todos_for_list(list_id)
    todo_sql= <<~SQL
      SELECT * FROM todos
      WHERE list_id = $1;
    SQL
    todos_result = query(todo_sql, list_id)

    todos = todos_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i,
        name: todo_tuple["name"],
        completed: todo_tuple["completed"] == "t" }
    end
  end
end
