require 'rails_helper'

RSpec.describe "packagings/new", type: :view do
  before(:each) do
    assign(:packaging, Packaging.new())
  end

  it "renders new packaging form" do
    render

    assert_select "form[action=?][method=?]", packagings_path, "post" do
    end
  end
end
