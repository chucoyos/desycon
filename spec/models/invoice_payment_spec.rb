require 'rails_helper'

RSpec.describe InvoicePayment, type: :model do
  describe 'validations' do
    it 'is valid when cumulative payments do not exceed invoice total' do
      invoice = create(:invoice, total: 1160)
      create(:invoice_payment, invoice: invoice, amount: 600)

      payment = build(:invoice_payment, invoice: invoice, amount: 560)

      expect(payment).to be_valid
    end

    it 'is invalid when cumulative payments exceed invoice total on create' do
      invoice = create(:invoice, total: 1160)
      create(:invoice_payment, invoice: invoice, amount: 1000)

      payment = build(:invoice_payment, invoice: invoice, amount: 200)

      expect(payment).not_to be_valid
      expect(payment.errors[:amount]).to include('excede el total de la factura')
    end

    it 'is invalid when updating a payment causes cumulative total to exceed invoice total' do
      invoice = create(:invoice, total: 1160)
      first_payment = create(:invoice_payment, invoice: invoice, amount: 600)
      second_payment = create(:invoice_payment, invoice: invoice, amount: 500)

      second_payment.amount = 700

      expect(second_payment).not_to be_valid
      expect(second_payment.errors[:amount]).to include('excede el total de la factura')
      expect(first_payment.reload.amount.to_d + second_payment.amount.to_d).to be > invoice.total.to_d
    end
  end
end
