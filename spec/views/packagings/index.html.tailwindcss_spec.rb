require 'rails_helper'

RSpec.describe "packagings/index", type: :view do
  before(:each) do
    assign(:packagings, [
      Packaging.create!(nombre: "Packaging One"),
      Packaging.create!(nombre: "Packaging Two")
    ])
  end

  it "renders a list of packagings" do
    render
    cell_selector = 'div>p'
  end
end
