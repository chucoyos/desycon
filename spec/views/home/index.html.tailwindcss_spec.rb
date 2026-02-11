require 'rails_helper'

RSpec.describe "home/index.html.tailwindcss", type: :view do
  it "renders the home page" do
    render template: "home/index"

    expect(rendered).to include("Global DYC")
  end
end
