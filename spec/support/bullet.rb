RSpec.configure do |config|
  config.around(:each, type: :request) do |example|
    spec_path = File.expand_path(example.metadata[:file_path])
    consolidator_specs_path = Rails.root.join("spec/requests/api/v1/consolidator").to_s

    unless spec_path.start_with?("#{consolidator_specs_path}/")
      example.run
      next
    end

    Bullet.enable = true
    Bullet.raise = true
    Bullet.start_request

    begin
      example.run
    ensure
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
      Bullet.raise = false
      Bullet.enable = false
    end
  end
end
