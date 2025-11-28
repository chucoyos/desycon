require 'rails_helper'

RSpec.describe "ports/index", type: :view do
  before(:each) do
    assign(:ports, [
      Port.create!(),
      Port.create!()
    ])
  end

  it "renders a list of ports" do
    render
    cell_selector = 'div>p'
  end
end
