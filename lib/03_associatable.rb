require_relative '02_searchable'
require 'active_support/inflector'
require 'byebug'

# Phase IIIa
class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    self.class_name.to_s.constantize
  end

  def table_name
    self.class_name.to_s.downcase + "s"
  end
end

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

module Associatable
  # Phase IIIb
  def belongs_to(name, options = {})
    self.assoc_options[name] = BelongsToOptions.new(name, options)
    define_method(name) do
      option = self.class.assoc_options[name]
      fk = option.send(:foreign_key)
      mc = option.model_class
      mc.where(option.primary_key => self.send(option.foreign_key)).first
    end
  end

  def has_many(name, options = {})
    option = HasManyOptions.new(name, self.name, options)
    define_method(name) do
      f_key = option.send(:foreign_key)
      m_class = option.model_class
      m_class.where(f_key => self.send(option.primary_key))
    end
  end

  def assoc_options
    @assoc_options ||= {}
    @assoc_options
  end
end

class SQLObject
  # Mixin Associatable here...
  extend Associatable
end
