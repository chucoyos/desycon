require 'rails_helper'

RSpec.describe "entities/new.html.tailwindcss", type: :view do
  it "renders the new entity page" do
    user = create(:user, :executive)
    allow(view).to receive(:current_user).and_return(user)

    assign(:entity, Entity.new)

    render template: "entities/new"

    expect(rendered).to include("Nueva Entidad")
  end
end
