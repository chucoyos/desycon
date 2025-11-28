require 'rails_helper'

RSpec.describe "ports/show", type: :view do
  before(:each) do
    assign(:port, Port.create!(name: "Veracruz", code: "MXVER", country_code: "MX"))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/MXVER/)
    expect(rendered).to match(/Veracruz/)
  end
end
