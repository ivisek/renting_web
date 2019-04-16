task :update_calendar_events => :environment do
	# bundle exec rails runner 'lib/google_calendar/calendar.rb'
	load 'lib/google_calendar/calendar.rb'
	# puts "bla"
end