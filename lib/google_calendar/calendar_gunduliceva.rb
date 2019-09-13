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


## update public available calendar

main_calendar_id = 'apartments.gunduliceva@gmail.com'

page_token = nil
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

airbnb_calendars = {
  1 => airbnb_calendar_1,
  2 => airbnb_calendar_2,
  3 => airbnb_calendar_3,
  4 => airbnb_calendar_4,
  5 => airbnb_calendar_5
}

all_airbnb_events = []
all_cleaning_events = []
all_new_arrivals_events = []

(1..5).each do |room|
  airbnb_cal_file = open(airbnb_calendars[room]) {|f| f.read }
  airbnb_events = Icalendar::Event.parse(airbnb_cal_file)

  airbnb_events.each do |event|

    start_date = event.dtstart
    end_date = event.dtend

    next if end_date.to_date < start_date.to_date # some new bug in airbnb calendar??

    next if end_date < Date.today + 1.day # +1 day because of cleaning day

    flag = "N/A"

    if !event.description.blank?
      flag = 'airbnb'
      nights_count = (start_date.to_date...end_date.to_date).count
      all_cleaning_events << {:start => {:date_time => (end_date + 8.hours).to_datetime, :time_zone => 'GMT+02:00/Belgrade'}, :end => {:date_time => (end_date + 13.hours).to_datetime, :time_zone => 'GMT+02:00/Belgrade'}, :summary => "Room #{room}"}
      all_new_arrivals_events << {:start => {:date => start_date}, :end => {:date => start_date}, :summary => "Room #{room} for #{nights_count} nights"}
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
end

# airbnb_events.reject! {|event| event[:end][:date] < Date.today } ## remove all old events from array - checkout date is in the past

### END get airbnb calendar

all_events = all_airbnb_events

# all_events = all_events.sort_by {|e| e[:description]}.reverse.uniq {|e| e[:end] and e[:start]}


## delete all events that are currently on google calendar but not on airbnb or booking
    # page_token = nil
begin
  result = service.list_events(main_calendar_id, page_token: page_token)
  result.items.each do |ge|
    # print e.summary + "\n"
    next if ge.end.date.blank? or (Date.parse(ge.start.date) < Date.today) # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
    if !all_events.select {|item| item[:start][:date].to_s == ge.start.date.to_s and item[:end][:date].to_s == ge.end.date.to_s and item[:summary] == ge.summary}.first
      # try to avoid deleting booking events
      next if DateTime.now.in_time_zone("CET").hour > 20
      service.delete_event(main_calendar_id, ge.id)
    end
  end
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?
    # service.delete_event(main_calendar_id, ge.id)


## must reload new calendar status - some events are deleted above
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

  if !result.items.select {|item| item.start.date.to_date.to_s == ev[:start][:date].to_s and item.end.date.to_date.to_s == ev[:end][:date].to_s and item.summary == ev[:summary]}.first
    event = Google::Apis::CalendarV3::Event.new(ev)
    service.insert_event(main_calendar_id, event)
  end
end

# update cleaning calendar

cleaning_calendar_id = 'f40o70phjrasd4v6r3q6q4bk08@group.calendar.google.com'

page_token = nil
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
begin
  result = service.list_events(cleaning_calendar_id, page_token: page_token)
  result.items.each do |ge|
    # print e.summary + "\n"
    next if ge.end.date.blank? or (Date.parse(ge.end.date) < Date.today) # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
    if !all_cleaning_events.select {|item| item[:start][:date_time].to_s == ge.start.date_time.to_s and item[:end][:date_time].to_s == ge.end.date_time.to_s and item[:summary] == ge.summary}.first
      # try to avoid deleting booking events
      next if DateTime.now.in_time_zone("CET").hour > 20
      service.delete_event(cleaning_calendar_id, ge.id)
    end
  end
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## must reload new calendar status - some events are deleted above
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

  if !result.items.select {|item| item.start.date_time.to_date.to_s == ev[:start][:date_time].to_s and item.end.date.to_date_time.to_s == ev[:end][:date_time].to_s and item.summary == ev[:summary]}.first
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

page_token = nil
begin
  result = service.list_events(arrivals_calendar_id, page_token: page_token)
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## delete all events that are currently on google calendar but not on airbnb or booking
    # page_token = nil
begin
  result = service.list_events(arrivals_calendar_id, page_token: page_token)
  result.items.each do |ge|
    next if ge.end.date.blank? or (Date.parse(ge.end.date) < Date.today) # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
    if !all_new_arrivals_events.select {|item| item[:start][:date].to_s == ge.start.date.to_s and item[:end][:date].to_s == ge.end.date.to_s and item[:summary] == ge.summary}.first
      # try to avoid deleting booking events
      next if DateTime.now.in_time_zone("CET").hour > 20
      service.delete_event(arrivals_calendar_id, ge.id)
    end
  end
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## must reload new calendar status - some events are deleted above
begin
  result = service.list_events(arrivals_calendar_id, page_token: page_token)
  
  if result.next_page_token != page_token
    page_token = result.next_page_token
  else
    page_token = nil
  end
end while !page_token.nil?

## add all events from booking and airbnb which are currently not on google calendar
all_new_arrivals_events.each do |ev|

  if !result.items.select {|item| item.start.date.to_date.to_s == ev[:start][:date].to_s and item.end.date.to_date.to_s == ev[:end][:date].to_s and item.summary == ev[:summary]}.first
    event = Google::Apis::CalendarV3::Event.new(ev)
    service.insert_event(arrivals_calendar_id, event)
  end
end

# delete all available events
# result.items.each do |e|
#   service.delete_event(arrivals_calendar_id, e.id)
# end


puts "DONE!!"