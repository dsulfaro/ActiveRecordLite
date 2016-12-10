## Active Record Lite

### SQL Object
SQL Object is what will interact with the database. (analogous to `ActiveRecord::Base`). Basically, it retrieves data from the database and turns it into a Ruby object for easy manipulation.

First, I defined `table_name` and `table_name=` methods which are simply stored as instance variables in the class (not ivar of an object of the class). Our classes will inherit from this SQLObject class thus, coverting the class name to the correct table name. I used the `String#stringify` method from 'active_support/inflector':

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
I moved onto implementing ActiveRecord Associations here with `belongs_to` and `has_many`. `AssocObjects` is a class that will hold relevant information for both associations: `#foreign_key`, `#class_name`, and `#primary_key`. `BelongsToOptions` and `HasManyOptions` are children classes of `AssocObjects` and only exist to provide default values for the attributes listed above:
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

Now, I implement the actual `belongs_to` and `has_many` relationships which exist in a module `Associatable`, and their implementations are nearly the same. I first instantiate either a `BelongsToOptions` object or a `HasManyOptions` object passing in the name of the association and an options hash (if the user specifies one).

Then, I use `define_method` on the name. This method then gets the foreign_key from the object created earlier, the `model_class`, and performs a `#where` query on the model_class to get the appropriate info:
```ruby
def has_many(name, options = {})
  option = HasManyOptions.new(name, self.name, options)
  define_method(name) do
    fk = option.send(:foreign_key)
    mc = option.model_class
    mc.where(fk => self.send(option.primary_key))
  end
end
```

#### has_one_through
Last is the `has_one_through` association which combines the previous two. The goal is to be able to do the following:
```ruby
class Comment < SQLObject
  belongs_to :post, :foreign_key => :post_id
  has_one_through :author, :user, :post

  finalize!
end

class Post < SQLObject
  self.table_name = "posts"

  belongs_to :user

  finalize!
end

class User < SQLObject
  finalize!
end

comment.author # => the user that authored the comment
```
I needed to store the options from `belongs_to` because, since I'm making use of both associations, I need to be able to access them separately:
```ruby
class Comment < SQLObject
  belongs_to :post, :foreign_key => :post_id

  finalize!
end

post_options = Comment.assoc_options[:post]
post_options.foreign_key # => :post_id
post_options.class_name # => "Post"
post_options.primary_key # => :id
```

I want to perform what is essentially the following query:
```SQL
SELECT
  table1.*
FROM
  table2
JOIN
  table1 ON table2.foreign_key = table1.primary_key
WHERE
  table2.primary_key = ?
```
I get all of the data I need to fill in those fields using the previously defined  `assoc_methods`:
```ruby
through_options = self.class.assoc_options[through_name]
source_options = through_options.model_class.assoc_options[source_name]
```
Then I get all of the parameters needed for the above query from these two options, parse the result, and return the query solution. The full code for the method is below.
```ruby
def has_one_through(name, through_name, source_name)
  define_method(name) do

    through_options = self.class.assoc_options[through_name]
    source_options = through_options.model_class.assoc_options[source_name]

    table1 = through_options.table_name
    table2 = source_options.table_name

    primary_key1 = through_options.primary_key
    primary_key2 = source_options.primary_key

    foreign_key1 = through_options.foreign_key
    foreign_key2 = source_options.foreign_key

    key_value = self.send(foreign_key1)

    result = DBConnection.execute(<<-SQL, key_value)
      SELECT
        #{table2}.*
      FROM
        #{table1}
      JOIN
        #{table2} ON #{table1}.#{foreign_key2} = #{table2}.#{primary_key2}
      WHERE
        #{table1}.#{primary_key1} = ?
    SQL
    source_options.model_class.parse_all(result).first
  end
end
```
