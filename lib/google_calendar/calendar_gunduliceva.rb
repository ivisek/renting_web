require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'date'
require 'fileutils'
require 'open-uri'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'apartments gunduliceva'.freeze
CREDENTIALS_PATH = 'lib/google_calendar/credentials_gunduliceva.json'.freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = 'token_gunduliceva.yaml'.freeze
# SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

# Initialize the API
service = Google::Apis::CalendarV3::CalendarService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

main_calendar_id = 'apartments.gunduliceva@gmail.com'

page_token, result = nil
begin
  result = service.list_events(main_calendar_id, page_token: page_token)
  # result.items.each do |e|
  #   print e.summary + "\n"
  #   service.delete_event(main_calendar_id, e.id)
  # end
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

# result.items.map {|i| [i.start.date, i.summary]}

# delete all available events
# result.items.each do |e|
#   service.delete_event(main_calendar_id, e.id)
# end

## END update public available calendar

## get airbnb calendars

airbnb_calendar_1 = "https://www.airbnb.com/calendar/ical/38095723.ics?s=6ada0273ee59cbefdcbff41fdc99efc5"
airbnb_calendar_2 = "https://www.airbnb.com/calendar/ical/38070607.ics?s=0350233ecd7117a0deb8a2ab3fe59203"
airbnb_calendar_3 = "https://www.airbnb.com/calendar/ical/38097952.ics?s=ebc3f71b6fccf853477bf16286acaeb5"
airbnb_calendar_4 = "https://www.airbnb.com/calendar/ical/38069827.ics?s=8a89654dee390c24b237d6a96403d1f1"
airbnb_calendar_5 = "https://www.airbnb.com/calendar/ical/37616807.ics?s=c31cf62bf249427ccfc5d2a6d9ccfb9e"

booking_calendar_1 = ""
booking_calendar_2 = "https://admin.booking.com/hotel/hoteladmin/ical.html?t=d358eafb-b5b7-4d84-b7e4-4328f3f34909"
booking_calendar_3 = ""
booking_calendar_4 = "https://admin.booking.com/hotel/hoteladmin/ical.html?t=89973b48-94fa-4332-9f60-8b66f3fe11db"
booking_calendar_5 = "https://admin.booking.com/hotel/hoteladmin/ical.html?t=a1ca2c70-ec0e-41f2-b229-364463733cd9"

airbnb_calendars = {
  1 => airbnb_calendar_1,
  2 => airbnb_calendar_2,
  3 => airbnb_calendar_3,
  4 => airbnb_calendar_4,
  5 => airbnb_calendar_5
}

booking_calendars = {
  1 => booking_calendar_1,
  2 => booking_calendar_2,
  3 => booking_calendar_3,
  4 => booking_calendar_4,
  5 => booking_calendar_5
}

all_airbnb_events = []
all_booking_events = []
all_cleaning_events = []
all_new_arrivals_events = []
all_unavailable_date_ranges = []
all_available_dates = []

(1..5).each do |room|
  # airbnb:
  airbnb_cal_file = open(airbnb_calendars[room]) {|f| f.read }
  airbnb_events = Icalendar::Event.parse(airbnb_cal_file)

  airbnb_events.each do |event|

    start_date = event.dtstart
    end_date = event.dtend

    next if end_date.to_date < start_date.to_date # some new bug in airbnb calendar??

    next if end_date < Date.today # + 1.day # +1 day because of cleaning day

    flag = "N/A"

    unavailable_date_range = (start_date.to_date...end_date.to_date).to_a
    
    if (start_date.to_date < Date.today + 1.month)
      all_unavailable_date_ranges << {:room => room, :dates => unavailable_date_range}
    end

    if !event.description.blank?
      flag = 'airbnb'
      note = event.description.to_s.split("\n").last
      if note.match(/10 Min Walk/) # if no note available
        note = "?"
      end
      nights_count = (start_date.to_date...end_date.to_date).count
      all_cleaning_events << {:start => {:date_time => (end_date + 9.hours).to_datetime, :time_zone => 'GMT+02:00/Belgrade'}, :end => {:date_time => (end_date + 14.hours).to_datetime, :time_zone => 'GMT+02:00/Belgrade'}, :summary => "Room #{room}"}
      all_new_arrivals_events << {:start => {:date => start_date}, :end => {:date => start_date + 1.day}, :summary => "Room #{room} (#{note}) for #{nights_count} nights"}
    else
      next
    end

    airbnb_event = {
      summary: "Room #{room} (#{event.summary})",
      # location: '800 Howard St., San Francisco, CA 94103',
      description: "#{flag}" ,

      start: {
        # date: (start_date + 13.hours).to_datetime,
        date: start_date
        # time_zone: 'GMT+02:00/Belgrade',
      },
      end: {
        # date: (end_date + 8.hours).to_datetime,
        date: end_date
        # time_zone: 'GMT+02:00/Belgrade',
      }
    }

    all_airbnb_events << airbnb_event
  end

  ## booking:
  next if booking_calendars[room].blank? # still no calendars for 1 and 3

  booking_cal_file = open(booking_calendars[room]) {|f| f.read }
  booking_events = Icalendar::Event.parse(booking_cal_file)

  booking_events.each do |event|

    start_date = event.dtstart
    end_date = event.dtend

    next if end_date.to_date < start_date.to_date # some new bug in airbnb calendar??

    next if end_date < Date.today # + 1.day # +1 day because of cleaning day

    flag = "N/A"

    unavailable_date_range = (start_date.to_date...end_date.to_date).to_a
    
    if (start_date.to_date < Date.today + 1.month)
      all_unavailable_date_ranges << {:room => room, :dates => unavailable_date_range}
    end

    if !event.summary.blank?
      flag = 'booking'
      note = "" # event.description.to_s.split("\n").last
      # if note.match(/10 Min Walk/) # if no note available
      #   note = "?"
      # end
      nights_count = (start_date.to_date...end_date.to_date).count
      all_cleaning_events << {:start => {:date_time => (end_date + 9.hours).to_datetime, :time_zone => 'GMT+02:00/Belgrade'}, :end => {:date_time => (end_date + 14.hours).to_datetime, :time_zone => 'GMT+02:00/Belgrade'}, :summary => "Room #{room}"}
      all_new_arrivals_events << {:start => {:date => start_date}, :end => {:date => (start_date + 1.day)}, :summary => "Room #{room} (#{note}) for #{nights_count} nights"}
    else
      next
    end

    booking_event = {
      summary: "Room #{room} (#{event.summary})",
      # location: '800 Howard St., San Francisco, CA 94103',
      description: "#{flag}" ,

      start: {
        # date: (start_date + 13.hours).to_datetime,
        date: start_date
        # time_zone: 'GMT+02:00/Belgrade',
      },
      end: {
        # date: (end_date + 8.hours).to_datetime,
        date: end_date
        # time_zone: 'GMT+02:00/Belgrade',
      }
    }

    all_booking_events << booking_event
  end
end

# airbnb_events.reject! {|event| event[:end][:date] < Date.today } ## remove all old events from array - checkout date is in the past

### END get airbnb calendar

all_events = all_airbnb_events + all_booking_events

# all_events = all_events.sort_by {|e| e[:description]}.reverse.uniq {|e| e[:end] and e[:start]}

## delete all events that are currently on google calendar but not on airbnb or booking
    # page_token = nil

result.items.each do |ge|
  # print e.summary + "\n"
  next if ge.end.date.blank? or (Date.parse(ge.end.date) < Date.today) # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
  if !all_events.select {|item| item[:start][:date].to_date.to_s == Date.parse(ge.start.date).to_s and item[:end][:date].to_date.to_s == Date.parse(ge.end.date).to_s and item[:summary] == ge.summary}.first
    # try to avoid deleting booking events
    next if DateTime.now.in_time_zone("CET").hour > 20
    # puts "deleted...............#{ge.inspect}.............."
    service.delete_event(main_calendar_id, ge.id)
  end
end

# service.delete_event(main_calendar_id, ge.id)

## must reload new calendar status - some events are deleted above
page_token, result = nil
begin
  result = service.list_events(main_calendar_id, page_token: page_token)
  
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## add all events from booking and airbnb which are currently not on google calendar
all_events.each do |ev|

  # if some dates are blocked and some are on booking, airbnb makes longer event
  # booking doesn't show blocked dates
  # if !["booking", "airbnb"].include? ev[:description]
  #   matching_end_date = all_events.select {|e| (["booking", "airbnb"].include? e[:description])}.select {|ee| ev[:end][:date].to_s == ee[:end][:date].to_s}.first
  #   matching_start_date = all_events.select {|e| (["booking", "airbnb"].include? e[:description])}.select {|ee| ev[:start][:date].to_s == ee[:start][:date].to_s}.first

  #   if matching_start_date
  #     # if existing event on booking or airbnb with the same start date, get its end date and modify current start date to that date
  #     ev[:start][:date] = matching_start_date[:end][:date]
  #   end

  #   if matching_end_date
  #     # if existing event on booking or airbnb with the same end date, get its start date and modify current end date to that date
  #     ev[:end][:date] = matching_end_date[:start][:date]
  #   end

  # end

  if !result.items.select {|item| item.start.date.to_date.to_s == ev[:start][:date].to_date.to_s and item.end.date.to_date.to_s == ev[:end][:date].to_date.to_s and item.summary == ev[:summary]}.first
    event = Google::Apis::CalendarV3::Event.new(ev)
    service.insert_event(main_calendar_id, event)
  end
end

# update cleaning calendar

cleaning_calendar_id = 'f40o70phjrasd4v6r3q6q4bk08@group.calendar.google.com'

page_token, result = nil
begin
  result = service.list_events(cleaning_calendar_id, page_token: page_token)
  # result.items.each do |e|
  #   print e.summary + "\n"
  #   service.delete_event(main_calendar_id, e.id)
  # end
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## delete all events that are currently on google calendar but not on airbnb or booking
    # page_token = nil

result.items.each do |ge|
  # print e.summary + "\n"
  next if ge.end.date_time.blank? or (ge.end.date_time.to_date < Date.today) # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
  if !all_cleaning_events.select {|item| item[:start][:date_time].to_date.to_s == ge.start.date_time.to_date.to_s and item[:end][:date_time].to_date.to_s == ge.end.date_time.to_date.to_s and ge.summary.to_s.match("#{item[:summary].to_s}")}.first
    # try to avoid deleting booking events
    next if DateTime.now.in_time_zone("CET").hour > 20
    # puts "deleted........#{ge.inspect}.............."
    next if !ge.description.blank? # skip events that are updated manually by me.... some guests pay directly and that is not shown on airbnb/booking
    service.delete_event(cleaning_calendar_id, ge.id)
  end
end

## must reload new calendar status - some events are deleted above
page_token, result = nil
begin
  result = service.list_events(cleaning_calendar_id, page_token: page_token)
  
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## add all events from booking and airbnb which are currently not on google calendar
all_cleaning_events.each do |ev|

  if !result.items.select {|item| item.start.date_time.to_date.to_s == ev[:start][:date_time].to_date.to_s and item.end.date_time.to_date.to_s == ev[:end][:date_time].to_date.to_s and item.summary.to_s.match("#{ev[:summary].to_s}")}.first
    event = Google::Apis::CalendarV3::Event.new(ev)
    service.insert_event(cleaning_calendar_id, event)
  end
end

# delete all available events
# result.items.each do |e|
#   service.delete_event(cleaning_calendar_id, e.id)
# end


# update arrivals calendar

arrivals_calendar_id = 'ghea1dh2o2cht29c6utus98vb4@group.calendar.google.com'

page_token, result = nil
begin
  result = service.list_events(arrivals_calendar_id, page_token: page_token, single_events: true)
  if result.next_page_token != page_token
    page_token = result.next_page_token
    result = service.list_events(arrivals_calendar_id, page_token: page_token, single_events: true)
  else
    page_token = nil
  end
end while !page_token.nil?

# result.items.map {|i| [i.start.date, i.summary]}

## delete all events that are currently on google calendar but not on airbnb or booking
result.items.each do |ge|
  next if ge.end.date.blank? or (Date.parse(ge.end.date) < Date.today) # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
  if !all_new_arrivals_events.select {|item| item[:start][:date].to_date.to_s == Date.parse(ge.start.date).to_s and item[:summary] == ge.summary}.first
    # try to avoid deleting booking events
    next if DateTime.now.in_time_zone("CET").hour > 20

    next if !ge.description.blank? # added manually
    
    service.delete_event(arrivals_calendar_id, ge.id)
  end
end

## must reload new calendar status - some events are deleted above
page_token, result = nil
begin
  result = service.list_events(arrivals_calendar_id, page_token: page_token, single_events: true)
  
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## add all events from booking and airbnb which are currently not on google calendar
all_new_arrivals_events.each do |ev|

  if !result.items.select {|item| item.start.date.to_date.to_s == ev[:start][:date].to_date.to_s and item.summary == ev[:summary]}.first
    event = Google::Apis::CalendarV3::Event.new(ev)
    service.insert_event(arrivals_calendar_id, event)
  end
end

# delete all available events
# result.items.each do |e|
#   service.delete_event(arrivals_calendar_id, e.id)
# end


# update availability calendar

availability_calendar_id = '7jata0ic2re4s4lemt7jhmfct4@group.calendar.google.com'

page_token, result = nil
begin
  result = service.list_events(availability_calendar_id, page_token: page_token, single_events: true)
  if result.next_page_token != page_token
    page_token = result.next_page_token
    result = service.list_events(availability_calendar_id, page_token: page_token, single_events: true)
  else
    page_token = nil
  end
end while !page_token.nil?

all_unavailable_date_ranges.uniq!
all_unavailable_date_ranges.group_by {|d_r| d_r[:room]}.map {|el| el[1]}.each do |one_room|
  room_no = one_room.first[:room]
  all_unavailable_dates = one_room.map {|r| r[:dates]}

  (Date.today..(Date.today + 14.days)).to_a.each do |day|
    available = true
    if all_unavailable_dates.select {|range| range.include? day}.first
      available = false
      next
    end

    if available
      all_available_dates << {:room => room_no, :date => day}
    end
  end 
end

all_available_dates_ranges = [] # join days in ranges
start_iteration = false
first_iteration_day = nil

all_available_dates.each_with_index do |av_date, date_index|
  if date_index < all_available_dates.count-1 and ((av_date[:date] + 1.day) == all_available_dates[date_index+1][:date])
    if !start_iteration
      first_iteration_day = av_date[:date]
    end
    start_iteration = true
  else
    start_iteration = false
    all_available_dates_ranges << {:room => av_date[:room], :start => {:date => first_iteration_day || av_date[:date]}, :end => {:date => av_date[:date] +1.day}, :summary => "Room #{av_date[:room]} available"}
    first_iteration_day = nil
  end
end

## delete all events that are currently on google calendar but not on airbnb or booking
    # page_token = nil

result.items.each do |ge|
  next if ge.end.date.blank? or (Date.parse(ge.end.date) < Date.today) # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
  if !all_available_dates_ranges.select {|item| item[:start][:date].to_s == Date.parse(ge.start.date).to_s and item[:end][:date].to_s == Date.parse(ge.end.date) and item[:summary] == ge.summary}.first
    # try to avoid deleting booking events
    next if DateTime.now.in_time_zone("CET").hour > 20
    service.delete_event(availability_calendar_id, ge.id)
  end
end

## must reload new calendar status - some events are deleted above
page_token, result = nil
begin
  result = service.list_events(availability_calendar_id, page_token: page_token, single_events: true)
  
  if result.next_page_token != page_token
    page_token = result.next_page_token
    result = service.list_events(availability_calendar_id, page_token: page_token, single_events: true)
  else
    page_token = nil
  end
end while !page_token.nil?

## add all events from booking and airbnb which are currently not on google calendar
all_available_dates_ranges.each do |ev|

  if !result.items.select {|item| item.start.date.to_date.to_s == ev[:start][:date].to_s and item.end.date.to_date.to_s == ev[:end][:date].to_s and item.summary == ev[:summary]}.first
    event = Google::Apis::CalendarV3::Event.new(ev)
    service.insert_event(availability_calendar_id, event)
  end
end

# delete all available events
# result.items.each do |e|
#   service.delete_event(availability_calendar_id, e.id)
# end

## add all events from booking and airbnb which are currently not on google calendar
# all_available_dates_ranges.each do |ev|
#     event = Google::Apis::CalendarV3::Event.new(ev)
#     service.insert_event(availability_calendar_id, event)
# end


puts "DONE!!"
