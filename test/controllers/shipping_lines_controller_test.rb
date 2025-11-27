require "test_helper"

class ShippingLinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shipping_line = shipping_lines(:one)
  end

  test "should get index" do
    get shipping_lines_url
    assert_response :success
  end

  test "should get new" do
    get new_shipping_line_url
    assert_response :success
  end

  test "should create shipping_line" do
    assert_difference("ShippingLine.count") do
      post shipping_lines_url, params: { shipping_line: { name: @shipping_line.name } }
    end

    assert_redirected_to shipping_line_url(ShippingLine.last)
  end

  test "should show shipping_line" do
    get shipping_line_url(@shipping_line)
    assert_response :success
  end

  test "should get edit" do
    get edit_shipping_line_url(@shipping_line)
    assert_response :success
  end

  test "should update shipping_line" do
    patch shipping_line_url(@shipping_line), params: { shipping_line: { name: @shipping_line.name } }
    assert_redirected_to shipping_line_url(@shipping_line)
  end

  test "should destroy shipping_line" do
    assert_difference("ShippingLine.count", -1) do
      delete shipping_line_url(@shipping_line)
    end

    assert_redirected_to shipping_lines_url
  end
end
