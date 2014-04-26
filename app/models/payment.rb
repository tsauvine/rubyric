class Payment < PayPal::SDK::REST::Payment
  include ActiveModel::Validations

  def create
    return false if invalid?
    super
  end

  def error=(error)
    error["details"].each do |detail|
      errors.add detail["field"], detail["issue"]
    end if error and error["details"]
    super
  end

  def order=(order)
    self.intent = "sale"
    self.payer.payment_method = "paypal"
    self.transactions = {
      :amount => {
        :total => order.amount,
        :currency => "USD" },
      :item_list => {
        :items => { :name => "pizza", :sku => "pizza", :price => order.amount, :currency => "USD", :quantity => 1 }
      },
      :description => order.description
     }
     self.redirect_urls = {
       :return_url => order.return_url.sub(/:order_id/, order.id.to_s),
       :cancel_url => order.cancel_url.sub(/:order_id/, order.id.to_s)
     }
  end

end
