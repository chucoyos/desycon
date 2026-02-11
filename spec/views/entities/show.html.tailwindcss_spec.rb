require 'rails_helper'

RSpec.describe "entities/show.html.tailwindcss", type: :view do
  it "renders the entity name" do
    user = create(:user, :executive)
    entity = create(:entity)
    allow(view).to receive(:current_user).and_return(user)
    view.extend Pundit::Authorization
    allow(view).to receive(:policy).and_return(double(manage_brokers?: false))

    assign(:entity, entity)

    render template: "entities/show"

    expect(rendered).to include(entity.name)
  end
end
