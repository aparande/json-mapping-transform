require 'yaml'.freeze
require 'logger'.freeze
require 'conditions'.freeze

##
# Stores and applies a mapping to an input ruby Hash
class JsonMapping
  ##
  # Thrown when a transform is not found or not callable
  class TransformError < StandardError; end
  ##
  # Thrown when parsing an invalid path
  class PathError < StandardError; end
  ##
  # Thrown when the YAML transform is not formatted properly
  class FormatError < StandardError; end

  ##
  # @param [String] schema_path The path to the YAML schema
  # @param [Hash] transforms A hash of callable objects (Procs/Lambdas). Keys must match transform names specified in YAML
  def initialize(schema_path, transforms = {})
    schema = YAML.safe_load(File.read(schema_path))

    @conditions = (schema['conditions'] || {}).map do |key, value|
      [key, Object.const_get("Conditions::#{value['class']}").new(value['predicate'])]
    end.to_h

    @object_schemas = schema['objects']
    @transforms = transforms || {}
    @logger = Logger.new($stdout)
  end

  ##
  # @param [Hash] input_hash A ruby hash onto which the schema should be applied
  # @return [Array] An array of output hashes representing the mapped objects
  def apply(input_hash)
    raise FormatError, 'Must define objects under the \'objects\' name' if @object_schemas.nil?

    @object_schemas.map { |schema| parse_object(input_hash, schema) }.reduce(&:merge)
  end

  private

  ##
  # Maps an object schema to an object in the output
  # @param [Hash] input_hash The hash onto which the schema should be mapped
  # @param [Hash] schema A hash representing the schema which should be applied to the input
  # Raises +FormatError+ if +schema+ is not a +Hash+ or has no key +name+
  # @return [Hash] The output object
  def parse_object(input_hash, schema)
    raise FormatError, "Object should be a hash: #{schema}" unless schema.is_a? Hash
    raise FormatError, "Object needs a name: #{schema}" unless schema.key?('name')

    output = {}
    # Its an object
    if schema.key?('attributes')
      output[schema['name']] = schema['default']

      object_hash = parse_path(input_hash, schema['path'])
      return output if object_hash.nil?

      unless object_hash.is_a? Array
        object_hash = [object_hash]
      end

      attrs = []
      object_hash.each do |obj|
        attributes_hash = {}
        schema['attributes'].each do |attribute|
          attr_hash = parse_object(obj, attribute)
          attributes_hash = attributes_hash.merge(attr_hash)
        end
        attrs << attributes_hash
      end

      output[schema['name']] = attrs.length == 1 && schema['path'][-1] != '*' ? attrs[0] : attrs
    else # Its a value
      output = map_value(input_hash, schema)
    end

    output
  end

  ##
  # Maps a schema to a single field in the output schema
  # @param [Hash] input_hash The input hash to be mapped
  # @param [Hash] schema The schema which should be applied
  # @return [Hash] A Hash which represents the applied schema
  def map_value(input_hash, schema)
    raise FormatError, "Schema should be a hash: #{schema}" unless schema.is_a? Hash

    output = {}
    output[schema['name']] = schema['default']
    return output if schema['path'].nil?

    value = parse_path(input_hash, schema['path'])
    return output if value.nil?

    if schema.key?('conditions')
      value = apply_conditions(value, schema['conditions']) || output[schema['name']]
    end

    if schema.key?('transform') && value != output[schema['name']]
      raise TransformError, "Undefined transform named #{schema['transform']}" unless @transforms.key?(schema['transform'])
      raise TransformError, 'Transforms should respond to the \'call\' method' unless @transforms[schema['transform']].respond_to?(:call)

      value = @transforms[schema['transform']].call(value)
    end

    output[schema['name']] = value
    output
  end

  ##
  # @param [Hash] input_hash The input hash
  # @param [String] path The path at which to grab the value
  # @return [Any] The value at the particular path
  def parse_path(input_hash, path)
    raise ArgumentError, "path must be string, not #{path.class}" unless path.is_a? String

    parts = path.split('/')
    value = input_hash

    parts.each_with_index do |part, idx|
      if value.nil?
        @logger.warn("Could not find #{path} in #{input_hash}")
        break
      end

      if part == '*'
        raise PathError, "#{parts[0, idx].join('/')} in #{input_hash} is not an array" unless value.is_a? Array

        return value.map { |obj| parse_path(obj, parts[idx + 1..-1].join('/')) }
      else
        next if part.empty?

        if value.is_a? Array
          part = part.to_i

          if part >= value.length
            @logger.warn("Index went out of bounds while parsing #{path} in #{input_hash}")
            value = nil
            break
          end
        end

        value = value[part]
      end
    end
    value
  end

  ##
  # Applies conditions to a value
  # @param [Any] value A value to compare the condition predicates against
  # @param [Array] conds An array of conditions
  # @return [Array] If multiple conditions are satisfied
  # @return [Any] If one condition is satisfied
  # @return [nil] If no conditions are satisfied
  def apply_conditions(value, conds)
    output = []
    conds.each do |cond|
      input_val = value
      raise FormatError, "Conditions are a hash: #{cond}" unless cond.is_a? Hash
      raise Conditions::ConditionError, "Unknown condition named #{cond['name']}" unless @conditions.key?(cond['name'])

      condition = @conditions[cond['name']]

      input_val = [input_val] unless input_val.is_a? Array
      input_val = input_val.select do |x|
        x = parse_path(x, cond['field']) if cond.key?('field')
        condition.apply(x)
      end

      next if input_val.empty?

      # Maintain the original data-type of the value (i.e Array or single element)
      input_val = input_val[0] if input_val.length == 1 && !value.is_a?(Array)
      output << (cond['output'] || input_val)
    end

    return (output.length == 1 ? output[0] : output) unless output.empty?
  end
end
