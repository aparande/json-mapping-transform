require 'conditions'

RSpec.describe 'InCondition' do
  it 'requires Array predicates' do
    expect { Conditions::InCondition.new('not an array') }.to raise_error(Conditions::ConditionError)
  end

  context '#apply' do
    let(:greetings_condition) { Conditions::InCondition.new(%w[hello howdy]) }
    it 'works with non-arrays inputs' do
      expect(greetings_condition.apply('hello')).to be true
      expect(greetings_condition.apply('goodbye')).to be false
    end

    it 'works with array inputs' do
      expect(greetings_condition.apply(%w[hello goodbye'])).to be true
      expect(greetings_condition.apply(%w[goodbye farewell])).to be false
    end
  end
end

RSpec.describe 'RegexCondition' do
  it 'requires string predicates' do
    expect { Conditions::RegexCondition.new('(.*') }.to raise_error(Conditions::ConditionError)
  end

  context '#apply' do
    let(:digit_condition) { Conditions::RegexCondition.new('^\d+$') }
    it 'matches inputs' do
      expect(digit_condition.apply('12345')).to be true
      expect(digit_condition.apply('astrs')).to be false
      expect(digit_condition.apply('astrs1234')).to be false
    end
  end
end

RSpec.describe 'AnyCondition' do
  context '#apply' do
    it 'matches inputs' do
      condition = Conditions::AnyCondition.new(nil)
      expect(condition.apply(true)).to be true
      expect(condition.apply([true, false])).to be true
      expect(condition.apply('truthy')).to be true
    end
  end
end

RSpec.describe 'LessThanCondition' do
  it 'requires numeric predicates' do
    expect { Conditions::LessThanCondition.new('asdf') }.to raise_error(Conditions::ConditionError)
  end

  context '#apply' do
    it 'matches inputs' do
      condition = Conditions::LessThanCondition.new(100)
      expect(condition.apply(0)).to be true
      expect(condition.apply(20)).to be true
      expect(condition.apply(150)).to be false
      expect(condition.apply(100)).to be false
    end
  end
end

RSpec.describe 'GreaterThanCondition' do
  it 'requires numeric predicates' do
    expect { Conditions::GreaterThanCondition.new('asdf') }.to raise_error(Conditions::ConditionError)
  end

  context '#apply' do
    it 'matches inputs' do
      condition = Conditions::GreaterThanCondition.new(0)
      expect(condition.apply(1)).to be true
      expect(condition.apply(2)).to be true
      expect(condition.apply(-1)).to be false
      expect(condition.apply(0)).to be false
    end
  end
end

RSpec.describe 'NotCondition' do
  it 'requires a condition predicate' do
    expect { Conditions::OrCondition.new('asddf') }.to raise_error(Conditions::ConditionError)
    expect { Conditions::OrCondition.new({ 'class' => 'FakeCondition' }) }.to raise_error(Conditions::ConditionError)
  end

  context '#apply' do
    it 'matches inputs' do
      condition = Conditions::NotCondition.new({ 'class' => 'RegexCondition', 'predicate' => '^\d+$' })
      expect(condition.apply('12345')).to be false
      expect(condition.apply('84')).to be false
      expect(condition.apply('1234.1234')).to be true
      expect(condition.apply('asdfads')).to be true
    end
  end
end

RSpec.describe 'OrCondition' do
  it 'requires an array of conditions as predicates' do
    expect { Conditions::OrCondition.new('asddf') }.to raise_error(Conditions::ConditionError)
    expect { Conditions::OrCondition.new([{ 'class' => 'AnyCondition' }]) }.to raise_error(Conditions::ConditionError)
    expect { Conditions::OrCondition.new([{ 'class' => 'FakeCondition' }, { 'class' => 'FakeCondition' }]) }.to raise_error(NameError)
  end

  context '#apply' do
    it 'matches inputs' do
      condition = Conditions::OrCondition.new(
        [
          { 'class' => 'RegexCondition', 'predicate' => '^\d+$' },
          { 'class' => 'RegexCondition', 'predicate' => '^\d+\.\d+$' }
        ]
      )

      expect(condition.apply('12345')).to be true
      expect(condition.apply('1234.1234')).to be true
      expect(condition.apply('asdfads')).to be false
    end
  end
end

RSpec.describe 'AndCondition' do
  it 'requires an array of conditions as predicates' do
    expect { Conditions::AndCondition.new('asddf') }.to raise_error(Conditions::ConditionError)
    expect { Conditions::AndCondition.new([{ 'class' => 'AnyCondition' }]) }.to raise_error(Conditions::ConditionError)
    expect { Conditions::AndCondition.new([{ 'class' => 'FakeCondition' }, { 'class' => 'FakeCondition' }]) }.to raise_error
  end

  context '#apply' do
    it 'matches inputs' do
      condition = Conditions::AndCondition.new(
        [
          { 'class' => 'GreaterThanCondition', 'predicate' => 0 },
          { 'class' => 'LessThanCondition', 'predicate' => 5 }
        ]
      )

      expect(condition.apply(4)).to be true
      expect(condition.apply(-1)).to be false
      expect(condition.apply(4.9999)).to be true
    end
  end
end
