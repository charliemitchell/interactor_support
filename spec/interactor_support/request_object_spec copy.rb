# Dummy request objects for testing purposes.

class BuyerRequest
  include InteractorSupport::RequestObject

  # Transform: strip the name; for email, strip then downcase.
  attribute :name, transform: :strip
  attribute :email, transform: [:strip, :downcase]

  validates :name, :email, presence: true
  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP
end

class PurchaseOrderRequest
  include InteractorSupport::RequestObject

  # Transform order_number using strip.
  attribute :order_number, transform: :strip

  validates :order_number, presence: true
end

class OrderRequest
  include InteractorSupport::RequestObject

  attribute :user_id
  attribute :office_id
  # Nested request object: an array of PurchaseOrderRequest.
  attribute :purchase_orders, type: PurchaseOrderRequest, array: true

  validates :user_id, :office_id, presence: true
  validates :purchase_orders, presence: true, length: { minimum: 1 }
end

RSpec.describe(InteractorSupport::RequestObject) do
  describe "attribute transformation" do
    context "when using a single transform" do
      it "strips the value for a symbol transform" do
        # NOTE: BuyerRequest#initialize calls valid? automatically.
        buyer = BuyerRequest.new(name: "  John Doe  ", email: "john@example.com")
        expect(buyer.name).to(eq("John Doe"))
      end
    end

    context "when using an array of transforms" do
      it "applies all transform methods in order" do
        buyer = BuyerRequest.new(name: "  Jane Doe  ", email: "  JANE@EXAMPLE.COM  ")
        expect(buyer.email).to(eq("jane@example.com"))
      end
    end

    context "when the value does not respond to a transform method" do
      it "leaves the value unchanged if the transform method is not defined" do
        class DummyRequest
          include InteractorSupport::RequestObject
          attribute :number, transform: :strip
          validates :number, presence: true
        end

        dummy = DummyRequest.new(number: 1234)
        expect(dummy.number).to(eq(1234))
      end
    end
  end

  describe "typecasting and array support" do
    context "when using a type without array" do
      it "wraps the given hash in the type's new instance" do
        po = PurchaseOrderRequest.new(order_number: "  PO123  ")
        expect(po.order_number).to(eq("PO123"))
      end
    end

    context "when using a type with array: true" do
      it "casts each element of the array to a new instance of the type" do
        order_attrs = {
          user_id: 1,
          office_id: 2,
          purchase_orders: [
            { order_number: "  PO001  " },
            { order_number: "PO002" },
          ],
        }
        order = OrderRequest.new(order_attrs)
        expect(order.purchase_orders).to(be_an(Array))
        expect(order.purchase_orders.size).to(eq(2))
        order.purchase_orders.each do |po|
          expect(po).to(be_a(PurchaseOrderRequest))
        end
        expect(order.purchase_orders.map(&:order_number)).to(eq(["PO001", "PO002"]))
      end

      it "wraps a single element in an array if necessary" do
        order_attrs = {
          user_id: 1,
          office_id: 2,
          purchase_orders: [{ order_number: " PO_SINGLE " }],
        }
        order = OrderRequest.new(order_attrs)
        expect(order.purchase_orders).to(be_an(Array))
        expect(order.purchase_orders.size).to(eq(1))
        expect(order.purchase_orders.first.order_number).to(eq("PO_SINGLE"))
      end
    end
  end

  describe "validations and automatic error raising" do
    context "when all validations pass" do
      it "creates the object successfully" do
        expect { BuyerRequest.new(name: "Alice", email: "alice@example.com") }.not_to(raise_error)
      end

      it "allows nested request objects to pass validations" do
        order_attrs = {
          user_id: 1,
          office_id: 2,
          purchase_orders: [
            { order_number: "PO100" },
            { order_number: "PO101" },
          ],
        }
        expect { OrderRequest.new(order_attrs) }.not_to(raise_error)
      end
    end

    context "when validations fail" do
      it "raises ActiveModel::ValidationError in the initializer" do
        expect do
          BuyerRequest.new(name: "", email: "invalid_email")
        end.to(raise_error(ActiveModel::ValidationError)) do |error|
          msgs = error.model.errors.full_messages
          expect(msgs).to(include("Name can't be blank"))
          expect(msgs).to(include("Email is invalid"))
        end
      end

      it "raises error for nested validations failure" do
        order_attrs = {
          user_id: nil, # missing user_id triggers error
          office_id: 2,
          purchase_orders: [
            { order_number: "PO100" },
            { order_number: nil }, # invalid purchase order (blank order_number)
          ],
        }
        expect do
          OrderRequest.new(order_attrs)
        end.to(raise_error(ActiveModel::ValidationError)) do |error|
          msgs = error.model.errors.full_messages
          # The error may be for missing user_id, purchase_orders length, or both.
          expect(msgs.any? { |m| m =~ /can't be blank/ }).to(be_truthy)
        end
      end
    end
  end

  describe "examples demonstrating ActiveModel validations" do
    it "shows a complete example with nested request objects" do
      params = {
        user_id: 10,
        office_id: 5,
        purchase_orders: [
          { order_number: "  PO555  " },
          { order_number: "PO556" },
        ],
      }
      order = OrderRequest.new(params)
      expect(order.user_id).to(eq(10))
      expect(order.office_id).to(eq(5))
      expect(order.purchase_orders.map(&:order_number)).to(eq(["PO555", "PO556"]))
      expect(order).to(be_valid)
    end

    it "demonstrates failure and shows error messages" do
      params = {
        user_id: 10,
        office_id: 5,
        purchase_orders: [], # empty array should trigger length validation
      }
      expect do
        OrderRequest.new(params)
      end.to(raise_error(ActiveModel::ValidationError)) do |error|
        # Expect at least one error message to mention "too short"
        expect(error.model.errors.full_messages.join(" ")).to(match(/too short/i))
      end
    end
  end
end
