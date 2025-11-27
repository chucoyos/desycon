require "pundit/rspec"

RSpec::Matchers.define :permit_action do |action|
  match do |policy|
    policy.public_send("#{action}?")
  end

  failure_message do |policy|
    "expected #{policy.class} to permit #{action} for #{policy.user.inspect} but it didn't"
  end

  failure_message_when_negated do |policy|
    "expected #{policy.class} not to permit #{action} for #{policy.user.inspect} but it did"
  end
end
