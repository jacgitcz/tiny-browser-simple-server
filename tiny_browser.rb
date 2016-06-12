require "socket"
require "json"

def decode_status(initial_line)
	status = []
	match_result = /^HTTP\/\d+\.\d+\s+(\d+)\s+(\S.+)$/.match(initial_line)
	if match_result.nil?
		[]
	else
		status[0] = match_result[1]
		status[1] = match_result[2]
		status
	end
end

def decode_headers(response_lines)
	headers = {}
	i = 1
	line = response_lines[i]
	bad_header_count = 0
	while line.length > 0 do
		match_result = /^(\S+):\s+(\S.+)$/.match(line)
		if match_result.nil?
			bad_header_count += 1
			bad_header_key = "Bad-Header" + bad_header_count.to_s
			headers[bad_header_key] = bad_header_count.to_s
		else
			headers[match_result[1]] = match_result[2]
		end
		i += 1
		line = response_lines[i]
	end
	headers
end

def create_headers(header_req)
	header_str = ""
	header_req.each_pair do |header, value |
		header_str << header + ": " + value.to_s + "\r\n"
	end
	header_str
end

def get_viking_info
	print "Enter the Viking's name and email: "
	input = gets.chomp
	parts = input.split(" ")
	name = parts[0..-2].join(" ")
	email = parts[-1]
	viking_details = {}
	viking_details[:name] = name
	viking_details[:email] = email
	viking_hash = {}
	viking_hash[:viking] = viking_details
	return viking_hash.to_json
end


host = "localhost"
port = 2000
from = "From: jaconnor44@gmail.com\r\n"
agent = "User-Agent: RubyTiny/1.0\r\n"

puts "Welcome to the tiny browser!"
command = ""
while command != "q"
	print "Enter command (g <filename> to GET, p to POST, q to quit) : "
	input = gets.chomp
	parts = input.split(" ")
	command = parts[0]
	case command
	when "g"
		path = parts[1]
		request = "GET #{path} HTTP/1.0\r\n"
		header_str = create_headers({"From" => "jaconnor44@gmail.com", "User-Agent" => "RubyTiny/1.0"})
		get_req = request + header_str + "\r\n\r\n"
		socket = TCPSocket.open(host, port)
		socket.print(get_req)
		response_lines = []
		while line = socket.gets do
			response_lines << line.chomp
		end

		status = decode_status(response_lines[0])
		if status[0] != "200"
			puts "An error occurred: error code #{status[0]}, error message: #{status[1]}"
		else
			headers = decode_headers(response_lines)
			body = response_lines[headers.length+2..-1].join("\n")
			puts body
		end
	when "p"
		post_content = get_viking_info

		request = "POST dummy HTTP/1.0\r\n"

		header_req = {"Date" => "#{Time.now}", "From" => "jaconnor44@gmail.com",
		              "User-Agent" => "RubyTiny/1.0"}
		header_req["Content-Type"] = "application/json"
		header_req["Content-Length"] = post_content.length.to_s
		header_str = create_headers(header_req)
		
		post_msg = request + header_str + "\r\n" + post_content + "\r\n"
		
		socket = TCPSocket.open(host, port)
		socket.print(post_msg)
		response = socket.read
		response_lines = response.lines.map {|l| l.chomp}
		status = decode_status(response_lines[0])
		if status[0] != "200"
			puts "An error occurred: error code #{status[0]}, error message: #{status[1]}"
		else
			headers = decode_headers(response_lines)
			body = response_lines[headers.length+2..-1].join("\n")
			puts body
		end
	when "q" # quit
	else
		puts "I'm sorry, I don't recognise that command."
	end
end
