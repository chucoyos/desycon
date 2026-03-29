require 'rails_helper'

RSpec.describe "customs_agents/dashboard.html.tailwindcss", type: :view do
  it "renders the dashboard header" do
    user = create(:user, :customs_broker)
    allow(view).to receive(:current_user).and_return(user)

    assign(:total_partidas, 0)
    assign(:in_revalidation_process, 0)
    assign(:revalidated_total, 0)
    assign(:dispatched_total, 0)
    assign(:bl_house_lines, Kaminari.paginate_array([]).page(1))

    render template: "customs_agents/dashboard"

    expect(rendered).to include("Dashboard Agencia Aduanal")
  end
end
