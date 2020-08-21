##
# Stores conditions accessible to +JsonMapper+
module Conditions
  ##
  # Thrown when a condition encounters an error
  class ConditionError < StandardError; end

  ##
  # Abstract class from which all conditions inherit
  class BaseCondition
    ##
    # @param [Any] predicate A predicate value which will be compared against input values
    def initialize(predicate)
      @predicate = predicate
    end

    def apply(_) true; end
  end

  ##
  # Checks if an element (or elements of an array) belong to an array
  # Can be used as an "equals to" condition
  class InCondition < BaseCondition
    ##
    # @param [Array] predicate An array predicate
    def initialize(predicate)
      raise ConditionError, "In condition value must be an Array, not #{predicate.class}" unless predicate.is_a? Array

      super(predicate)
    end

    ##
    # @param [Any, Array] value A value to be checked against the predicate
    # @return [true] if value and predicate have overlapping values
    # @return [false] if value and predicate have no overlapping values
    def apply(value)
      value = [value] unless value.is_a? Array
      (value & @predicate).any?
    end
  end

  ##
  # Compares a value against a regular expression
  class RegexCondition < BaseCondition
    ##
    # @param [String] predicate A valid regular expression
    def initialize(predicate)
      predicate = Regexp.new(predicate.to_s)
      super(predicate)
    rescue RegexpError => e
      raise ConditionError, e.inspect
    end

    ##
    # @param [String] value
    # @return [true] if value matches regular expression
    # @return [false] if value does not match regular expression
    def apply(value)
      @predicate.match?(value)
    end
  end

  ##
  # Checks if any values in the array are true
  class AnyCondition < BaseCondition
    ##
    # @param [Any, Array] value
    # @return [true] if value is truthy (or has at least one truthy value)
    # @return [false] if the value is not truthy (or has no truthy values)
    def apply(value)
      value = [value] unless value.is_a? Array
      value.any?
    end
  end

  ##
  # Checks if two conditions are true
  class AndCondition < BaseCondition
    ##
    # @param [Array] predicate An array of Hashes representating conditions (Greater than length 2)
    def initialize(predicate)
      raise ConditionError, 'And condition predicate must be an array of conditions' unless predicate.is_a?(Array) && predicate.length > 1

      predicate.map! { |x| Object.const_get("Conditions::#{x['class']}").new(x['predicate']) }
      super(predicate)
    end

    ##
    # @param [Any] value
    # @return [true] if +value+ matches all conditions
    # @return [false] if +value+ does not match one condition
    def apply(value)
      @predicate.map { |x| x.apply(value) }.all?
    end
  end

  ##
  # Checks if either or both of two conditions are true
  class OrCondition < BaseCondition
    ##
    # @param [Array] predicate An array of Hashes representating conditions (Greater than length 2)
    def initialize(predicate)
      raise ConditionError, 'Or condition predicate must be an array of conditions' unless predicate.is_a?(Array) && predicate.length > 1

      predicate.map! { |x| Object.const_get("Conditions::#{x['class']}").new(x['predicate']) }
      super(predicate)
    end

    ##
    # @param [Any] value
    # @return [true] if +value+ matches any condition
    # @return [false] if +value+ matches no conditions
    def apply(value)
      @predicate.map { |x| x.apply(value) }.any?
    end
  end

  ##
  # Checks if a condition is not true
  class NotCondition < BaseCondition
    ##
    # @param [Hash] predicate A hash representing a condition
    def initialize(predicate)
      raise ConditionError, 'Not condition predicate a condition' unless predicate.is_a?(Hash) && predicate.key?('class')

      predicate = Object.const_get("Conditions::#{predicate['class']}").new(predicate['predicate'])
      super(predicate)
    end

    ##
    # @param [Any] value
    # @return [true] if +value+ does not satisfy the condition
    # @return [false] if +value+ satisfies the condition
    def apply(value)
      !@predicate.apply(value)
    end
  end

  ##
  # Checks if value is less than a predicate
  class LessThanCondition < BaseCondition
    ##
    # @param [Numeric] predicate
    def initialize(predicate)
      raise ConditionError, 'LessThan condition predicate must a number' unless predicate.is_a?(Numeric)

      super(predicate)
    end

    ##
    # @param [Numeric] value
    # @return [true] if +value < predicate+
    # @return [false] if +value >= predicate+
    def apply(value)
      value < @predicate
    end
  end

  ##
  # Checks if value is greater than a predicate
  class GreaterThanCondition < BaseCondition
    ##
    # @param [Numeric] predicate
    def initialize(predicate)
      raise ConditionError, 'GreaterThan condition predicate must a number' unless predicate.is_a?(Numeric)

      super(predicate)
    end

    ##
    # @param [Numeric] value
    # @return [true] if +value > predicate+
    # @return [false] if +value <= predicate+
    def apply(value)
      value > @predicate
    end
  end
end
