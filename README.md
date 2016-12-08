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

Lastly, `#save` calls either `#update` or `#insert` depending on whether the object currently has an id or not. That way, the user can simply call `#save` rather than worrying about which of the other two to call:
```ruby
def save
  self.id.nil? ? self.insert : self.update
end
```

### Searchable
Searchable is a module that adds the `::where` class method to SQLObject by mixing in Searchable to SQLObject:
```ruby
module Searchable
  def where(params)
    where_line = params.keys.map { |key| "#{key} = ?"}
    where_line = where_line.join(" AND ")
    result = DBConnection.execute(<<-SQL, *params.values)
      SELECT *
      FROM #{table_name}
      WHERE #{where_line}
    SQL
    parse_all(result)
  end
end

class SQLObject
  extend Searchable
end
```
`where_line` takes all the attribute keys and maps them to the where line used in the heredoc SQL query and then the actual values are passed in with `*params.values`.

### Associations
I moved onto implementing ActiveRecord Associations here using `belongs_to` and `has_many`. `AssocObjects` is a class that will hold relevant information for both associations: `#foreign_key`, `#class_name`, and `#primary_key`. `BelongsToOptions` and `HasManyOptions` are children classes of `AssocObjects` and only exist to provide default values for the attributes listed above:
```ruby
class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    @foreign_key = options[:foreign_key] ? options[:foreign_key] : (name.to_s + "_id").to_sym
    @class_name = options[:class_name] ? options[:class_name] : name.to_s.capitalize
    @primary_key = options[:primary_key] ? options[:primary_key] : :id
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    @foreign_key = options[:foreign_key] ? options[:foreign_key] : (self_class_name.downcase + "_id").to_sym
    @class_name = options[:class_name] ? options[:class_name] : name[0..-2].to_s.capitalize
    @primary_key = options[:primary_key] ? options[:primary_key] : :id
  end
end
```
I allow the user to input custom values using `options = {}`, but defaults are provided as well.

I then implement `model_class` and `table_name` in `AssocObjects` to allow the following functionality:
```ruby
options = BelongsToOptions.new(:owner, :class_name => "User")
options.model_class # => User
options.table_name # => "users"
```
The user can now specify a different name for their associations.
