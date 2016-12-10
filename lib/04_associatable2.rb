require_relative '03_associatable'

# Phase IV
module Associatable
  # Remember to go back to 04_associatable to write ::assoc_options

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
end
