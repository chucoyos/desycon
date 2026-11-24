require "rails_helper"
require "capybara/selenium/driver"

module ChromeSessionResetFallback
  def reset!
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError => e
    raise unless e.message.include?("* is not a valid URL")

    Rails.logger.warn("Capybara: Chrome rechazó el origen comodín al limpiar la sesión; se reinicia el navegador.")
    quit
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeSessionResetFallback)

# System tests configuration
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end

# Base class for system tests
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ]
end
