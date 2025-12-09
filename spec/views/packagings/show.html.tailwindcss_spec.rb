require 'rails_helper'

RSpec.describe "packagings/show", type: :view do
  before(:each) do
    assign(:packaging, Packaging.create!(nombre: "Test Packaging"))
  end

  it "renders attributes in <p>" do
    render
  end
end
