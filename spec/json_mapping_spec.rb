require 'json_mapping'
require 'json'

RSpec.describe 'JsonMapping' do
  let(:simple_obj) do
    { 'key0' => 0, 'key1' => 1 }
  end

  let(:simple_yaml) do
    {
      'objects' => [
        {
          'name' => 'foo',
          'path' => '/key0',
          'default' => 'bar'
        }
      ]
    }
  end

  context '#map' do
    let(:store_fixture) do
      JSON.parse(File.read(File.expand_path('fixtures/files/store_data.json', __dir__)))
    end

    it 'succeeds with basic mapping' do
      path = File.expand_path('fixtures/files/mappings/basic.yml', __dir__)
      output = JsonMapping.new(path).apply(store_fixture)

      expect(output).to eq(
        {
          'name' => 'Trader Joe\'s',
          'location' => 'Berkeley, California',
          'weekly_visitors' => 5000,
          'store_id' => 1234,
          'employees' => ['Jim Shoes', 'Kay Oss'],
          'inventory' => [
            { 'item_name' => 'Apples', 'price' => 0.5, 'unit' => 'lb' },
            { 'item_name' => 'Oranges', 'price' => 2, 'unit' => 'lb' },
            { 'item_name' => 'Bag of Carrots', 'price' => 1.5, 'unit' => 'count' }
          ]
        }
      )
    end

    it 'loads defaults properly' do
      path = File.expand_path('fixtures/files/mappings/defaults.yml', __dir__)
      output = JsonMapping.new(path).apply(store_fixture)
      expect(output).to eq(
        {
          'name' => 'Trader Joe\'s',
          'profits' => 0
        }
      )
    end

    it 'can apply custom transforms' do
      path = File.expand_path('fixtures/files/mappings/transforms.yml', __dir__)
      transforms = {
        'listing_transform' => ->(list) { list.map { |x| "#{x['itemName']} at $#{x['price']}/#{x['unit']}" } }
      }
      output = JsonMapping.new(path, transforms).apply(store_fixture)
      expect(output).to eq(
        {
          'name' => 'Trader Joe\'s',
          'inventory' => ['Apples at $0.5/lb', 'Oranges at $2/lb', 'Bag of Carrots at $1.5/count']
        }
      )
    end

    it 'applies conditions properly' do
      path = File.expand_path('fixtures/files/mappings/conditions.yml', __dir__)
      output = JsonMapping.new(path).apply(store_fixture)
      expect(output).to eq(
        {
          'performance' => 'high',
          'cheap_food' => [
            { 'itemName' => 'Apples', 'price' => 0.5, 'unit' => 'lb' }
          ],
          'fruits' => [
            { 'itemName' => 'Apples', 'price' => 0.5, 'unit' => 'lb' },
            { 'itemName' => 'Oranges', 'price' => 2, 'unit' => 'lb' }
          ]
        }
      )
    end

    it 'keeps arrays as arrays even if there is one object' do
      store_fixture['inventory'] = [{ 'itemName' => 'Apples', 'price' => 1, 'unit' => 'lb', 'category' => 'fruit' }]
      path = File.expand_path('fixtures/files/mappings/basic.yml', __dir__)
      output = JsonMapping.new(path).apply(store_fixture)

      expect(output).to eq(
        {
          'name' => 'Trader Joe\'s',
          'location' => 'Berkeley, California',
          'weekly_visitors' => 5000,
          'store_id' => 1234,
          'employees' => ['Jim Shoes', 'Kay Oss'],
          'inventory' => [{ 'item_name' => 'Apples', 'price' => 1, 'unit' => 'lb' }]
        }
      )
    end

    context 'falls back on default when' do
      before do
        allow(File).to receive(:read).and_return('')
      end

      it 'encounters a null object' do
        simple_yaml['objects'][0]['path'] = '/key/dne'
        simple_yaml['objects'][0]['attributes'] = [{ 'name' => 'nested', 'default' => 'empty' }]
        allow(YAML).to receive(:safe_load).and_return(simple_yaml)

        json = JsonMapping.new('').apply(simple_obj)
        expect(json).to eq('foo' => 'bar')
      end

      it 'encountering a non-existent path' do
        simple_yaml['objects'][0]['path'] = '/key/dne'
        allow(YAML).to receive(:safe_load).and_return(simple_yaml)

        json = JsonMapping.new('').apply(simple_obj)
        expect(json).to eq('foo' => 'bar')
      end

      it 'indexing out of bounds' do
        simple_obj['arr'] = []
        simple_yaml['objects'][0]['path'] = '/arr/0'
        allow(YAML).to receive(:safe_load).and_return(simple_yaml)

        json = JsonMapping.new('').apply(simple_obj)
        expect(json).to eq('foo' => 'bar')
      end
    end

    context 'raises an exception when' do
      before do
        allow(File).to receive(:read).and_return('')
      end

      it 'there are no objects' do
        yaml = { 'empty' => 'object' }
        allow(YAML).to receive(:safe_load).and_return(yaml)
        expect { JsonMapping.new('').apply('') }.to raise_error(JsonMapping::FormatError)
      end

      it 'objects are not a hash' do
        yaml = { 'objects' => ['not a hash'] }
        allow(YAML).to receive(:safe_load).and_return(yaml)
        expect { JsonMapping.new('').apply('') }.to raise_error(JsonMapping::FormatError)
      end

      it 'objects are poorly formatted' do
        yaml = { 'objects' => [{ 'no name' => 'object' }] }
        allow(YAML).to receive(:safe_load).and_return(yaml)
        expect { JsonMapping.new('').apply('') }.to raise_error(JsonMapping::FormatError)
      end

      it 'attributes are not a hash' do
        yaml = { 'objects' => [['not a hash']] }
        allow(YAML).to receive(:safe_load).and_return(yaml)
        expect { JsonMapping.new('').apply('') }.to raise_error(JsonMapping::FormatError)
      end

      it 'has an undefined condition' do
        simple_yaml['objects'][0]['conditions'] = [{ 'name' => 'cond', 'output' => 'bar' }]
        allow(YAML).to receive(:safe_load).and_return(simple_yaml)
        expect { JsonMapping.new('').apply(simple_obj) }.to raise_error(Conditions::ConditionError)
      end

      it 'has uncallable transform' do
        simple_yaml['objects'][0]['transform'] = 't'
        allow(YAML).to receive(:safe_load).and_return(simple_yaml)
        expect { JsonMapping.new('', 't' => nil).apply(simple_obj) }.to raise_error(JsonMapping::TransformError)
      end

      it 'tries mapping a non-array' do
        simple_yaml['objects'][0]['path'] = 'key0/*'
        allow(YAML).to receive(:safe_load).and_return(simple_yaml)
        expect { JsonMapping.new('', 't' => nil).apply(simple_obj) }.to raise_error(JsonMapping::PathError)
      end
    end

    module Conditions
      class AppleCondition < BaseCondition
        def apply(value)
          puts value
          value.is_a?(Hash) && value['itemName'] == 'Apples'
        end
      end
    end

    it 'can use user-defined conditions' do
      path = File.expand_path('fixtures/files/mappings/custom_condition.yml', __dir__)
      output = JsonMapping.new(path).apply(store_fixture)
      expect(output['apple']).to eq([{ 'itemName' => 'Apples', 'price' => 0.5, 'unit' => 'lb' }])
    end

    it 'raises an error if the condition is not found' do
      path = File.expand_path('fixtures/files/mappings/undefined_condition.yml', __dir__)
      expect { JsonMapping.new(path).apply(store_fixture) }.to raise_error(NameError)
    end
  end
end
