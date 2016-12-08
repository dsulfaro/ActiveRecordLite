require_relative 'db_connection'
require 'active_support/inflector'

# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @columns ||= DBConnection.execute2(<<-SQL)
      SELECT *
      FROM #{table_name}
    SQL
      .first.map { |column| column.to_sym }
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) { self.attributes[column] }
      define_method("#{column}=") { |val| self.attributes[column] = val }
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
    # ...
  end

  def self.parse_all(results)
    # ...
  end

  def self.find(id)
    # ...
  end

  def initialize(params = {})
    params.each do |k, v|
      k = k.to_sym
      if self.class.columns.include?(k)
          self.send("#{k}=", v)
      else
        raise "unknown attribute '#{k}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    # ...
  end

  def insert
    # ...
  end

  def update
    # ...
  end

  def save
    # ...
  end
end
