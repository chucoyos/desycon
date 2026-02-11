require 'rails_helper'

RSpec.describe "entities/index.html.tailwindcss", type: :view do
  it "renders the entities header" do
    user = create(:user, :executive)
    allow(view).to receive(:current_user).and_return(user)
    view.extend Pundit::Authorization
    allow(view).to receive(:policy).and_return(double(update?: false, destroy?: false))

    assign(:per_page, 20)
    assign(:entities, Kaminari.paginate_array([ create(:entity) ]).page(1))

    render template: "entities/index"

    expect(rendered).to include("Entidades")
  end
end
