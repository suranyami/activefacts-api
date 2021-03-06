require 'delegate'
require 'date'
require 'securerandom'

unless defined? SecureRandom.uuid
  # I think this only applies to 1.8.6 (and JRuby/Rubinius in 1.8 mode) now:
  def SecureRandom.uuid
    hex(16).sub(/(........)(....)(....)(....)(............)/,'\1-\2-\3-\4-\5')
  end
end

# The Guid class is what it says on the packet, but you can assert a :new one.
class Guid
  def initialize(i = :new)
    if i == :new
      @value = SecureRandom.uuid.freeze
    elsif (v = i.to_s).length == 36 and !(v !~ /[^0-9a-f]/i)
      @value = v.clone.freeze
    else
      raise "Illegal non-Guid value #{i.inspect} given for Guid"
    end
  end

  def to_s
    @value
  end

  # if the value is unassigned, it equal?(:new).
  def equal? value
    @value == value
  end

  def inspect
    "\#<Guid #{@value}>"
  end

  def hash                              #:nodoc:
    @value.hash
  end

  def eql?(o)                           #:nodoc:
    to_s.eql?(o.to_s)
  end

#  def self.inherited(other)             #:nodoc:
#    def other.identifying_role_values(*args)
#      return nil if args == [:new]  # A new object has no identifying_role_values
#      if args.size == 1
#        return args[0] if args[0].is_a?(AutoCounter)
#        return args[0].send(self.basename.snakecase.to_sym) if args[0].respond_to?(self.basename.snakecase.to_sym)
#      end
#      return new(*args)
#    end
#    super
#  end

end
