## Active Record Lite

### attr_accessor
This was a quick first step. Using the `define_method`, `instance_variable_set`, and `instance_variable_get` methods, one can now define setters and getters simply by using `attr_accessor`.

### SQL Object
First, I defined `table_name` and `table_name=` methods which are simply stored as instance variables in the class (not ivar of an object of the class). Our classes will inherit from this SQLObject class thus, coverting the class name to the correct table name. I used the `String#stringify` method from 'active_support/inflector'

```ruby
class User < SQLObject
end

User.table_name # => "users"
