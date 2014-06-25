class OrdersController < ApplicationController
  before_filter :load_course
  before_filter :login_required
  
  # TODO: logging
  
  def load_course
    @course_instance = CourseInstance.find(params[:course_instance_id])
    @course = @course_instance.course
  end
  
  def index
    @orders = current_user.orders.all(:limit => 10, :order => "id DESC")
    @order = Order.new
  end

  def new
    @order = Order.new
    #current_user.orders.build
  end
  
  def create
    @order = Order.new(params[:order])
    @order.user = current_user
    @order.description = 'Medium course'
    @order.payment_method = 'paypal'
    @order.return_url = order_execute_url(":order_id")
    @order.cancel_url = order_cancel_url(":order_id")
    
    if @order.save
      if @order.approve_url
        redirect_to @order.approve_url
      else
        redirect_to orders_path, :notice => "Order[#{@order.description}] placed successfully"
      end
    else
      render :new, :error => @order.errors.to_a.join(", ")
    end
  end

  def execute
    order = current_user.orders.find(params[:order_id])
    
    if order.execute(params["PayerID"])
      redirect_to orders_path, :notice => "Order[#{order.description}] placed successfully"
    else
      redirect_to orders_path, :alert => order.payment.error.inspect
    end
  end

  def cancel
    order = current_user.orders.find(params[:order_id])
    
    unless order.state == "approved"
      order.state = "cancelled"
      order.save
    end
    
    redirect_to orders_path, :alert => "Order[#{order.description}] cancelled"
  end

  def show
    @order = current_user.orders.find(params[:id])
  end
end
