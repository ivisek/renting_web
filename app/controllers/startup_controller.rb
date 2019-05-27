class StartupController < ApplicationController
  
  def index
  end

  def register
    return if request.method == "GET"
    if params[:registration_data].blank? or params[:registration_data].reject {|k, v| v.blank?}.blank?
      flash[:warning] = "Invalid request! #{DateTime.now}"
      puts "invalid!!"
    else
  		RegisterMailer.new_guest(params[:registration_data]).deliver
  		flash[:success] = "Registration mail sent!"
    end
  end
end
