class RegisterMailer < ActionMailer::Base
  
  def new_guest(details)
    @body = details
    mail(
      :from => "Guest Registration <apartmentstino@gmail.com>",
      :to => "apartmentstino@gmail.com",
      :subject => "New Guest #{Date.today.strftime(("%d.%m.%Y"))}"
    )
  end
end