require "rails_helper"

RSpec.describe PackagingsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/packagings").to route_to("packagings#index")
    end

    it "routes to #new" do
      expect(get: "/packagings/new").to route_to("packagings#new")
    end

    it "routes to #show" do
      expect(get: "/packagings/1").to route_to("packagings#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/packagings/1/edit").to route_to("packagings#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/packagings").to route_to("packagings#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/packagings/1").to route_to("packagings#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/packagings/1").to route_to("packagings#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/packagings/1").to route_to("packagings#destroy", id: "1")
    end
  end
end
