require "rails_helper"

RSpec.describe "Aislamiento de sesión del navegador", type: :system do
  it "clears cookies and local storage when resetting a session" do
    visit new_user_session_path
    page.execute_script("localStorage.setItem('test-reset', 'value'); document.cookie = 'test_reset=value; path=/'")

    Capybara.reset_sessions!
    visit new_user_session_path

    expect(page.evaluate_script("localStorage.getItem('test-reset')")).to be_nil
    expect(page.evaluate_script("document.cookie")).not_to include("test_reset=value")
  end
end
