## Active Record Lite

### attr_accessor
This was a quick first step. Using the `define_method`, `instance_variable_set`, and `instance_variable_get` methods, one can now define setters and getters simply by using `attr_accessor`.

### SQL Object
First, I defined `table_name` and `table_name=` methods which are simply stored as instance variables in the class (not ivar of an object of the class). Our classes will inherit from this SQLObject class thus, coverting the class name to the correct table name. I used the `String#stringify` method from 'active_support/inflector'

```ruby
class User < SQLObject
end

User.table_name # => "users"
```

Next, I needed to be able to use getters and setters for the columns in the database. I did this by first fetching the columns, creating setters and getters using `define_method`, storing these columns as keys in an `@attributes` hash as in ivar, and then instantiating an object using an options hash. Now, I'm able to do something like the following:

```ruby
dan = User.new
dan.name = "Dan"
dan.age = 24

dan.name # => "Dan"
dan.age # => 24
```

Then, I implement #all method with retrieves all rows in the DB. This is done using a heredoc:
```ruby
DBConnection.execute(<<-SQL)
  SELECT *
  FROM #{table_name}
SQL
```
and then translating those results from a hash into an array of Ruby objects.

`find`, `insert`, and `update` are implemented using heredoc SQL queries as well though constructing the strings for insert and update were slightly tricker. For example:
```ruby
# insert
col_names = "(#{self.class.columns.join(', ')})"
questions_marks = ['?'] * self.class.columns.length
questions_marks = "(#{questions_marks.join(', ')})"
```
