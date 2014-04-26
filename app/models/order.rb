class Order < ActiveRecord::Base
  belongs_to :user

  validates_presence_of :amount, :description, :user_id
  after_create :create_payment

  attr_accessible :amount #, :description, :state, :payment_method
  attr_accessor :return_url, :cancel_url, :payment_method

  def payment
    @payment ||= payment_id && Payment.find(payment_id)
  end

  def create_payment
    new_payment = Payment.new( :order => self )
    if new_payment.create
      self.payment_id = new_payment.id
      self.state = new_payment.state
      save
    else
      errors.add :payment_method, new_payment.error["message"] if new_payment.error
      raise ActiveRecord::Rollback, "Can't place the order"
    end
  end

  def execute(payer_id)
    if payment.present? and payment.execute(:payer_id => payer_id)
      self.state = payment.state
      save
    else
      errors.add :description, payment.error.inspect
      false
    end
  end

  def approve_url
    payment.links.find{|link| link.method == "REDIRECT" }.try(:href)
  end

end 
