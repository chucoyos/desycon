require 'rails_helper'

RSpec.describe "ports/new", type: :view do
  before(:each) do
    assign(:port, Port.new())
  end

  it "renders new port form" do
    render

    assert_select "form[action=?][method=?]", ports_path, "post" do
    end
  end
end
