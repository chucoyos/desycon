require 'rails_helper'

RSpec.describe "packagings/edit", type: :view do
  let(:packaging) {
    Packaging.create!(nombre: "Test Packaging")
  }

  before(:each) do
    assign(:packaging, packaging)
  end

  it "renders the edit packaging form" do
    render

    assert_select "form[action=?][method=?]", packaging_path(packaging), "post" do
    end
  end
end
