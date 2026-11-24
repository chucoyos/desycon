require "rails_helper"
require "fugit"

RSpec.describe CustomsAgents::RecalculateAccessRestrictionsJob, type: :job do
  it "schedules four daily global recalculations in production and staging" do
    schedules = YAML.safe_load(ERB.new(Rails.root.join("config/recurring.yml").read).result)
    %w[production staging].each do |environment|
      task = schedules.fetch(environment).fetch("customs_agents_recalculate_access_restrictions")
      cron = Fugit.parse(task.fetch("schedule"))
      time = Time.local(2026, 11, 24)
      hours = 4.times.map do
        time = cron.next_time(time)
        time.to_local_time.hour
      end
      expect(hours).to eq([ 5, 10, 15, 20 ])
    end
  end

  it "runs after the five-hour interval between scheduled recalculations" do
    agency = create(:entity, :customs_agent, enforce_overdue_payment_rule: true)
    job = described_class.new
    allow(job).to receive(:previous_recurring_execution_at).and_return(5.hours.ago)

    expect(CustomsAgents::RestrictionEvaluatorService).to receive(:call).with(customs_agent: agency)
    job.perform
  end

  it "skips a recent global recalculation unless forced" do
    agency = create(:entity, :customs_agent, enforce_overdue_payment_rule: true)
    job = described_class.new
    allow(job).to receive(:previous_recurring_execution_at).and_return(1.hour.ago)
    allow(CustomsAgents::RestrictionEvaluatorService).to receive(:call)

    job.perform
    expect(CustomsAgents::RestrictionEvaluatorService).not_to have_received(:call)

    job.perform(force: true)
    expect(CustomsAgents::RestrictionEvaluatorService).to have_received(:call).with(customs_agent: agency).once
  end
end
