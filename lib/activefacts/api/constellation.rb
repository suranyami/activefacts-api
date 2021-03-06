#
#       ActiveFacts Runtime API
#       Constellation class
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#

module ActiveFacts
  module API      #:nodoc:
    # A Constellation is a population of instances of the ObjectType classes of a Vocabulary.
    # Every object_type class is either a Value type or an Entity type.
    #
    # Value types are uniquely identified by their value, and a constellation will only
    # ever have a single instance of a given value of that class.
    #
    # Entity instances are uniquely identified by their identifying roles, and again, a
    # constellation will only ever have a single entity instance for the values of those
    # identifying roles.
    #
    # As a result, you cannot "create" an object in a constellation - you merely _assert_
    # its existence. This is done using method_missing; @constellation.Thing(3) creates
    # an instance (or returns the existing instance) of Thing identified by the value 3.
    # You can also use the populate() method to apply a block of assertions.
    #
    # You can instance##retract any instance, and that removes it from the constellation (will
    # delete it from the database when the constellation is saved), and nullifies any
    # references to it.
    #
    # A Constellation may or not be valid according to the vocabulary's constraints,
    # but it may also represent a portion of a larger population (a database) with
    # which it may be merged to form a valid population. In other words, an invalid
    # Constellation may be invalid only because it lacks some of the facts.
    #
    class Constellation
      attr_reader :vocabulary
      # All instances are indexed in this hash, keyed by the class object.
      # Each instance is indexed for every supertype it has (including multiply-inherited ones).
      # It's a bad idea to try to modify these indexes!
      attr_reader :instances      # Can say c.instances[MyClass].each{|k, v| ... }
                                  # Can also say c.MyClass.each{|k, v| ... }

      # Create a new empty Constellation over the given Vocabulary
      def initialize(vocabulary)
        @vocabulary = vocabulary
        @instances = Hash.new do |h,k|
          unless k.is_a?(Class) and k.modspace == vocabulary
            raise "A constellation over #{@vocabulary.name} can only index instances of classes in that vocabulary, not #{k.inspect}"
          end
          h[k] = InstanceIndex.new(self, k)
        end
      end

      def inspect #:nodoc:
        "Constellation:#{object_id}"
      end

      # Evaluate assertions against the population of this Constellation
      def populate &block
        instance_eval(&block)
        self
      end

      # Delete instances from the constellation, nullifying (or cascading) the roles each plays
      def retract(*instances)
        Array(instances).each do |i|
          i.retract
        end
        self
      end

      # Constellations verbalise all members of all classes in alphabetical order, showing
      # non-identifying role values as well
      def verbalise
        "Constellation over #{vocabulary.name}:\n" +
        vocabulary.object_type.keys.sort.map do |object_type|
            klass = vocabulary.const_get(object_type)

            # REVISIT: It would be better not to rely on the role name pattern here:
            single_roles, multiple_roles = klass.roles.keys.sort_by(&:to_s).partition{|r| r.to_s !~ /\Aall_/ }
            single_roles -= klass.identifying_role_names if (klass.is_entity_type)
            # REVISIT: Need to include superclass roles also.

            instances = send(object_type.to_sym)
            next nil unless instances.size > 0
            "\tEvery #{object_type}:\n" +
              instances.map do |key, instance|
                  s = "\t\t" + instance.verbalise
                  if (single_roles.size > 0)
                    role_values = 
                      single_roles.map{|role|
                          [ role_name = role.to_s.camelcase,
                            value = instance.send(role)]
                        }.select{|role_name, value|
                          value
                        }.map{|role_name, value|
                          "#{role_name} = #{value ? value.verbalise : "nil"}"
                        }
                    s += " where " + role_values*", " if role_values.size > 0
                  end
                  s
                end * "\n"
          end.compact*"\n"
      end

      # This method removes the given instance from this constellation's indexes
      # It must be called before the identifying roles get deleted or nullified.
      def __retract(instance) #:nodoc:
        # REVISIT: Need to search, as key values are gone already. Is there a faster way?
        ([instance.class]+instance.class.supertypes_transitive).each do |klass|
          @instances[klass].delete_if{|k,v| v == instance }
        end
        # REVISIT: Need to nullify all the roles this object plays.
        # If mandatory on the counterpart side, this may/must propagate the delete (without mutual recursion!)
      end

      # If a missing method is the name of a class in the vocabulary module for this constellation,
      # then we want to access the collection of instances of that class, and perhaps assert new ones.
      # With no parameters, return the collection of all instances of that object_type.
      # With parameters, assert an instance of the object_type identified by the values passed as args.
      def method_missing(m, *args, &b)
        klass = @vocabulary.const_get(m)
        if klass and klass.is_a?(Class) and klass.respond_to?(:assert_instance)
          (class << self; self; end).
            send(:define_method, sym = m.to_sym) do |*args|
              instance_index = @instances[klass]
              if args.size == 0
                # Return the collection of all instances of this class in the constellation:
                instance_index
              else
                # Assert a new ground fact (object_type instance) of the specified class, identified by args:
                instance_index.assert(*args)
              end
            end

          # This is the last time it'll be missing, so call it.
          send(sym, *args, &b)
        else
          super
        end
      end
    end
  end
end
