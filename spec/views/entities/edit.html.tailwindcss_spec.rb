require 'rails_helper'

RSpec.describe "entities/edit.html.tailwindcss", type: :view do
  it "renders the edit entity page" do
    user = create(:user, :executive)
    allow(view).to receive(:current_user).and_return(user)

    assign(:entity, create(:entity))

    render template: "entities/edit"

    expect(rendered).to include("Editar Entidad")
  end
end
