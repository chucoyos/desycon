require 'rails_helper'

RSpec.describe "ports/edit", type: :view do
  let(:port) {
    Port.create!()
  }

  before(:each) do
    assign(:port, port)
  end

  it "renders the edit port form" do
    render

    assert_select "form[action=?][method=?]", port_path(port), "post" do
    end
  end
end
