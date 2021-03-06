require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'date'
require 'fileutils'
require 'open-uri'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'apartments tino'.freeze
CREDENTIALS_PATH = 'lib/google_calendar/credentials_kruziceva.json'.freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = 'token_kruziceva.yaml'.freeze
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

main_calendar_id = 'apartmentstino@gmail.com'

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

### get airbnb calendar ## https://github.com/icalendar/icalendar

# calendar_id = 'de0a8jsvche186m2p4goa9jgnr06713r@import.calendar.google.com'
# response = service.list_events(calendar_id,
                               # max_results: 100,
                               # single_events: true,
                               # order_by: 'startTime',
                               # time_min: DateTime.now.rfc3339)


# puts 'Upcoming events:'
# puts 'No upcoming events found' if response.items.empty?
# response.items.each do |event|
#   start = event.start.date || event.start.date_time
#   end_date = event.end.date || event.end.date_time
#   puts "Not available: (#{start} - #{end_date})"
# end

# puts "#{service.list_calendar_lists.next_sync_token}"


airbnb_calendar = "https://www.airbnb.com/calendar/ical/162372.ics?s=32b743b183163ef304896c2cdd7d4c12"

# Open a file or pass a string to the parser
airbnb_cal_file = open(airbnb_calendar) {|f| f.read }

airbnb_events = Icalendar::Event.parse(airbnb_cal_file)

all_airbnb_events = []

airbnb_events.each do |event|
  start_date = event.dtstart
  end_date = event.dtend

  # next if end_date < Date.today

  flag = "N/A"

  if !event.description.blank?
    flag = 'airbnb'
  end

  event = {
    summary: "Not available (#{flag})",
    # location: '800 Howard St., San Francisco, CA 94103',
    description: "#{flag}" ,

    start: {
      date: start_date
      # time_zone: 'GMT+02:00/Belgrade',
    },
    end: {
      date: end_date
      # time_zone: 'GMT+02:00/Belgrade',
    }
  }

  all_airbnb_events << event
  # result = service.insert_event(main_calendar_id, event)
end

all_airbnb_events.reject! {|event| event[:end][:date] < Date.today } ## remove all old events from array - checkout date is in the past

### END get airbnb calendar

### get booking calendar

booking_calendar = "https://admin.booking.com/hotel/hoteladmin/ical.html?t=TJHwK-iTbu42Kg2xvoCdymIphBTNNY7QgyQi6xwBQ8wWyVsfXt3MQVFSEwlYbrYgRby0S_LtlaE3Zz5_A_TJpuEgdvY6ej_6oES3tI-3vCk25dR_v6Aj50PC71VMhecbxqQKzJJQUwYMlwwGBZd0DLXtq6ieFggWFt6ihA"

booking_cal_file = open(booking_calendar) {|f| f.read }

booking_events = Icalendar::Event.parse(booking_cal_file)

all_booking_events = []

booking_events.each do |event|
  start_date = event.dtstart
  end_date = event.dtend

  flag = "N/A"

  if !event.summary.blank?
    flag = 'booking'
  end

  event = {
    summary: "Not available (#{flag})",
    # location: '800 Howard St., San Francisco, CA 94103',
    description: "#{flag}" ,

    start: {
      date: start_date
      # time_zone: 'GMT+02:00/Belgrade',
    },
    end: {
      date: end_date
      # time_zone: 'GMT+02:00/Belgrade',
    }
  }

  all_booking_events << event
end

## don't have to remove all old events from array - checkout date is in the past - because booking does not send these

### END get booking calendar

all_events = all_airbnb_events + all_booking_events

all_events = all_events.sort_by {|e| e[:description]}.reverse.uniq {|e| e[:end] and e[:start]}

## delete all events that are currently on google calendar but not on airbnb or booking
    # page_token = nil
    begin
      result = service.list_events(main_calendar_id, page_token: page_token)
      result.items.each do |ge|
        # print e.summary + "\n"
        next if Date.parse(ge.end.date) < Date.today # next if Date.parse(ge.start.date) < Date.today # # skip old events because they are not even in the all_events array
        if !all_events.select {|item| item[:start][:date].to_s == Date.parse(ge.start.date).to_s and item[:end][:date].to_s == Date.parse(ge.end.date).to_s and item[:description] == ge.description}.first
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

  # if some dates are blocked and some are on booking, airbnb makes on longer event
  # booking doesn't show blocked dates
  if !["booking", "airbnb"].include? ev[:description]
    matching_end_date = all_events.select {|e| (["booking", "airbnb"].include? e[:description])}.select {|ee| ev[:end][:date].to_s == ee[:end][:date].to_s}.first
    matching_start_date = all_events.select {|e| (["booking", "airbnb"].include? e[:description])}.select {|ee| ev[:start][:date].to_s == ee[:start][:date].to_s}.first

    if matching_start_date
      # if existing event on booking or airbnb with the same start date, get its end date and modify current start date to that date
      ev[:start][:date] = matching_start_date[:end][:date]
    end

    if matching_end_date
      # if existing event on booking or airbnb with the same end date, get its start date and modify current end date to that date
      ev[:end][:date] = matching_end_date[:start][:date]
    end

  end

  if !result.items.select {|item| Date.parse(item.start.date).to_s == ev[:start][:date].to_s and Date.parse(item.end.date).to_s == ev[:end][:date].to_s and item.description == ev[:description]}.first
    event = Google::Apis::CalendarV3::Event.new(ev)
    service.insert_event(main_calendar_id, event)
  end
end





# busy_dates = response

# busy_dates.items.each do |event|
#   start_date = event.start.date || event.start.date_time
#   end_date = event.end.date || event.end.date_time

#   start_date = Date.parse(start_date)
#   end_date = Date.parse(end_date)

#   event = Google::Apis::CalendarV3::Event.new(
#     summary: 'Not available (A)',
#     # location: '800 Howard St., San Francisco, CA 94103',
#     description: 'A',

#     start: {
#       date: start_date
#       # time_zone: 'GMT+02:00/Belgrade',
#     },
#     end: {
#       date: end_date
#       # time_zone: 'GMT+02:00/Belgrade',
#     },
#     # recurrence: [
#     #   'RRULE:FREQ=DAILY;COUNT=2'
#     # ],
#     # attendees: [
#     #   {email: 'lpage@example.com'},
#     #   {email: 'sbrin@example.com'},
#     # ],
#     # reminders: {
#     #   use_default: false,
#     #   overrides: [
#     #     {method' => 'email', 'minutes: 24 * 60},
#     #     {method' => 'popup', 'minutes: 10},
#     #   ],
#     # },
#   )

#   result = service.insert_event(availability_calendar_id, event)
#   puts "Event created: #{result.html_link}"
# end

puts "DONE!!"