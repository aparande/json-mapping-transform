# JSON Map Transform

## Overview
When building data pipelines, it is often useful to extract and transfrom data from an input JSON and output it in a different format. The standard process for doing this in Ruby is to write a series of if-else logic coupled with for-loops. This code ends up being largely redundant, confusing, and difficult to maintain or change. This Gem provides an easy and extensible solution to this problem by allowing you to define your mapping in YAML and apply it to any JSON object in a single line of code.

The general format of the transform mapping looks as follows:
``` yaml
---
conditions:
  condition_name:
    class: (required)
    predicate: (optional)
objects:
- name: (required)
  path: (optional)
  default: (optional)
  attributes: (optional)
  transform: (optional)
  conditions: (optional)
  - name: (required)
    output: (optional)
    field: (optional)
```

## Installation
Add the gem to the Gemfile
```ruby
gem 'json-mapping-transform'
```
Require the mapping in your code
```ruby
require 'json_mapping'
```

## Objects
Objects are the output keys of the mapping. `JsonMapper#map` will output a single Ruby Hash when applied to an input.
The following rules apply to objects:
- Each object has a name that translates to its key in the output JSON
- The **path** specifies the input key in the source JSON that the object corresponds to
  - Paths are defined from the top level of the JSON: `/`
  - When `*` is included in the path, the result will be an array
  - When a path is not found (or not proviided), the object evaluates to `nil`
- Objects can have a **default** value which is returned if the path evaluates to `nil`
- Objects can have **attributes** which are a list of more objects (nested JSON objects)
  - **Note:** Paths in nested objects are relative to the path of the top-level object

## Conditions
Conditions are `if` statements performed on an extracted value. They are defined as a hash in the mapping file.
- By default, conditions are evaluated against the object path
  - If **field** is specified, the condition is evaluated against the path relative to the object path
- If the extracted value satisfies the condition, the output will be set to **output** (to the extracted value if output is not specified)
- If the extracted value does not satisfy the condition, the output will be set to the object's default
- If the extracted value is `nil`, conditions are not evaluated
- Conditions are referenced by **name** in the object definition
- If multiple conditions are defined and satisfied, the output will be an array

There are several built-in condition types which can be used for the `class` field of the condition.
- `InCondition`: Check if an object/Array is in/intersects with the **predicate**, an array
- `RegexCondition`: Check if a string matches the **predicate**, a regular expression
- `AnyCondition`: Check if an object/Array is/contains a truthy value
- `LessThanCondition`: Check if a `Numeric` is less than the **predicate**, another `Numeric`
- `GreaterThanCondition`: Check if a `Numeric` is less than the **predicate**, another `Numeric`
- `AndCondition`: Check if an object satisfies all conditions provided in the **predicate**
- `OrCondition`: Check if an object satisfies at least one condition provided in the **predicate**
- `NotCondition`: Check if an object does not satisfy the condition provided as the **predicate**

Developers can create their own custom conditions by extending `BaseCondition` inside of the `Conditions` module
  
## Transforms
- Transforms are arbitrary blocks of code which act on the extracted value for an object
- Transforms are applied after conditions (i.e they will only be applied if at least one condition is satisfied)
- If the extracted value is `nil` (or all conditions fail), then transforms are not evaluated
- Transforms are referenced by name in YAML. You must pass in a hash of them to the `JsonMapper` during initialization

## Failure Cases
### Graceful Failures
The mapping will gracefully fail (fall back on default) when
1. Encountering a null object in the original object
2. Encountering non-existent paths
3. Indexing an array out of bounds

### Exceptions
The mapping will raise an exception when
1. The YAML map is not formatted properly (`JsonMapper::FormatError`)
2. A condition is referenced but not defined (`Conditions::ConditionError`)
3. Unknown condition type (`NameError`)
4. A condition is defined with an incorrect predicate (`Conditions::ConditionError`)
5. A condition is given a value it can't compare to the predicate (`Conditions::ConditionError`)
6. A provided transform is not callable (`JsonMapper::TransformError`)
7. The `*` operator is used on a non-array (`JsonMapper::PathError`)
8. An exception is encountered while applying a transform (`StandardError`)

## Examples
For all the examples provided below, this is the input JSON that is being mapped:
```json
{
  "name": "Trader Joe's",
  "location": "Berkeley, California",
  "weeklyVisitors": 5000,
  "storeId": 1234,
  "employees": [
    { "name": "Jim Shoes" },
    { "name": "Kay Oss" }
  ],
  "inventory": [
    { "itemName": "Apples", "price": 0.5, "unit": "lb" },
    { "itemName": "Oranges", "price": 2, "unit": "lb" },
    { "itemName": "Bag of Carrots", "price": 1.5, "unit": "count" }
  ]
}
```
### Basic Example
An simple example which just converts between two objects
#### Mapping
```yaml
---
objects:
- name: name
  path: "/name"
- name: profits
  default: 0
- name: location
  path: "/location"
- name: weekly_visitors
  path: "/weeklyVisitors"
- name: store_id
  path: "/storeId"
- name: employees
  path: "/employees/*/name"
- name: inventory
  path: "/inventory/*"
  attributes:
  - name: item_name
    path: /itemName
  - name: price
    path: /price
  - name: unit
    path: /unit
```
#### Output
```json
{
  "name": "Trader Joe\'s",
  "profits": 0,
  "location": "Berkeley, California",
  "weekly_visitors": 5000,
  "store_id": 1234,
  "employees": ["Jim Shoes", "Kay Oss"],
  "inventory": [
    { "item_name": "Apples", "price": 0.5, "unit": "lb" },
    { "item_name": "Oranges", "price": 2, "unit": "lb" },
    { "item_name": "Bag of Carrots", "price": 1.5, "unit": "count" }
  ]
}
```
### Transforms Example
An example of a custom transformation
#### Mapping
```yaml
---
objects:
- name: name
  path: "/name"
- name: inventory
  path: "/inventory/*/"
  transform: listing_transform
```
#### Code
```ruby
transforms = {
  'listing_transform' => ->(list) { list.map { |x| "#{x['itemName']} at $#{x['price']}/#{x['unit']}" } }
}
output = JsonMapping.new(path, transforms).map(store_fixture)
```
#### Output
```json
{
  "name": "Trader Joe\'s",
  "inventory": ["Apples at $0.5/lb", "Oranges at $2/lb", "Bag of Carrots at $1.5/count"]
}
```
### Conditions Example
An example using conditions
```yaml
---
conditions:
  apple_condition:
    class: AppleCondition
  high_performance_condition:
    class: AndCondition
    predicate:
    - class: LessThanCondition
      predicate: 10000
    - class: GreaterThanCondition
      predicate: 1000
  
objects:
- name: performance
  path: "/weeklyVisitors"
  conditions:
  - name: high_performance_condition
    output: high
- name: apple
  path: "/inventory"
  conditions:
  - name: apple_condition
```
#### Code
```ruby
module Conditions
  class AppleCondition < BaseCondition
    def apply(value)
      puts value
      value.is_a?(Hash) && value['itemName'] == 'Apples'
    end
  end
end

output = JsonMapping.new(path).map(store_fixture)
```
#### Output
```json
{
  "performance": "high",
  "apple": [{ "itemName": "Apples", "price": 0.5, "unit": "lb" }]
}
```
