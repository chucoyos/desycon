require 'rails_helper'

RSpec.describe "ports/index", type: :view do
  before(:each) do
    assign(:ports, [
      Port.create!(name: "Veracruz", code: "MXVER", country_code: "MX"),
      Port.create!(name: "Manzanillo", code: "MXZLO", country_code: "MX")
    ])
  end

  it "renders a list of ports" do
    render
    expect(rendered).to match(/MXVER/)
    expect(rendered).to match(/MXZLO/)
  end
end
