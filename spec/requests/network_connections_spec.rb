require 'rails_helper'

RSpec.describe "NetworkConnections", type: :request do
  describe "GET /network_connections" do
    it "works! (now write some real specs)" do
      get network_connections_path
      expect(response).to have_http_status(200)
    end
  end
end
