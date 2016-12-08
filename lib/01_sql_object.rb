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
    parse_all(DBConnection.execute(<<-SQL)
      SELECT *
      FROM #{table_name}
    SQL
    )
  end

  def self.parse_all(results)
    results.map do |r|
      self.new(r)
    end
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id)
      SELECT *
      FROM #{table_name}
      WHERE id = ?
    SQL
    return self.new(result[0]) if result != []
    return nil
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
    values = []
    self.class.columns.map { |col| values << self.send(col) }
    values
  end

  def insert
    col_names = "(#{self.class.columns.join(', ')})"
    questions_marks = ['?'] * self.class.columns.length
    questions_marks = "(#{questions_marks.join(', ')})"
    DBConnection::execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} #{col_names}
      VALUES
        #{questions_marks}
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map { |att| "#{att} = ?"}.join(', ')
    DBConnection::execute(<<-SQL, *attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end
  end
  
end
