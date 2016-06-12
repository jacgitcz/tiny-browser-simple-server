require "socket"
require "json"

VALID_CMDS = ["GET", "POST"]
BAD_REQ = "400 Bad Request"
OK_MSG = "200 OK"
NOT_FOUND = "404 Not Found"
SERVER_ERR = "500 Server Error"

def decode_initial(line)
	initial_line = []
	match_result = /^([A-Z]+)\s+(\S+)\s+HTTP\/\d+\.\d+$/.match(line)
	if match_result.nil?
		[]
	else
		initial_line[0] = match_result[1]
		initial_line[1] = match_result[2]
		initial_line
	end
end

def construct_template(params)
	# construct replacement HTML
	viking = params[:viking]
	name = viking[:name]
	email = viking[:email]
	html = "<li>Name: #{name}</li><li>Email: #{email}</li>"
	# get the template
	template = File.open("thanks.html","r") {|f| f.read}
	template.sub!("<%= yield %>",html) # patch the template
	template
end

def create_headers(header_req)
	header_str = ""
	header_req.each_pair do |header, value |
		header_str << header + ": " + value.to_s + "\r\n"
	end
	header_str
end

def process_request(client, cmd, path, headers)
	case cmd
	when "GET"
		begin
			message = File.open(path, "r") {|file| file.read }
			send_status(client, OK_MSG)
			header_req = {"Date" => "#{Time.now}", "Content-Type" => "text/html",
	                      "Content-Length" => "#{message.length}"}
	        header_str = create_headers(header_req)
			client.puts header_str + "\r\n" + message + "\r\n"
		rescue
			if File.exists?(path)
				send_status(client, SERVER_ERR)
			else
				send_status(client, NOT_FOUND)
			end
		end
	when "POST"
		send_status(client, OK_MSG)
		contents = read_contents(headers, client)
		params = {}
		params.merge!(JSON.parse(contents, :symbolize_names => true))
		
		template = construct_template(params)

		header_req = {"Date" => "#{Time.now}", "Content-Type" => "text/html",
	                  "Content-Length" => "#{template.length}"}
	    header_str = create_headers(header_req)

		reply = header_str + "\r\n" + template + "\r\n"
		client.puts reply
	else
		send_status(client, BAD_REQ)
	end
end

def send_status(client, status)
	status_message = "HTTP/1.1 " + status
	client.puts status_message
end


def read_headers(lines)
	headers = {}
	line = lines[1]
	i = 1
	while line.length > 0 do
		match_result = /^(\S+):\s+(\S+)$/.match(line)
		if !match_result.nil?
			label = match_result[1]
			value = match_result[2]
			headers[label] = value
		end
		i += 1
		line = lines[i]
	end
	headers
end

def read_contents(headers, client)
	contents = ""
	if headers.key?("Content-Length")
		content_len = headers["Content-Length"].to_i
		if content_len > 0
			amount_read = 0			
			while amount_read < content_len do
				line = client.gets
				contents << line
				amount_read += line.length
			end
		end
	end
	return contents
end

server = TCPServer.open(2000)
loop {
	client = server.accept
	message_lines = []
	while line = client.gets do
		message_lines << line.chomp
		if line == "\r\n"
			break
		end
	end
	# p message_lines
	initial_line = decode_initial(message_lines[0])
	if initial_line.length > 1
		command = initial_line[0]
		path = initial_line[1]
		if VALID_CMDS.include?(command)
			headers = read_headers(message_lines)
			process_request(client, command, path, headers)
		else
			send_status(client, BAD_REQ)
		end
	else
		send_status(client, BAD_REQ)
	end
	client.close
}

