class StartupController < ApplicationController
  
  def index
  end

  def register
  	details = params.except(:utf8, :authenticity_token, :commit, :controller, :action)
  	RegisterMailer.new_guest(details).deliver
  end
  
end
