require 'byebug'

class AttrAccessorObject
  def self.my_attr_accessor(*names)

    names.each do |name|
      define_method(name) { instance_variable_get("@#{name}") }
    end

    names.each do |name|
      define_method(name.to_s + "=") { |val| instance_variable_set("@#{name}", val)  }
    end

  end
end
