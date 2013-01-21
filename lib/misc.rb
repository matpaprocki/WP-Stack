def loadFile file
	begin
		raise "Could not find #{file}" unless FileTest.readable? file
		load file
	rescue Exception => e
		puts '[Error] ' + e.message
		exit 1
	end
end

def relative_path(from_str, to_str)
    require 'pathname'

    Pathname.new(to_str).relative_path_from(Pathname.new(from_str)).to_s
end
