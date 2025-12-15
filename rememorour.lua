local function readline(prompt)
	io.stderr:write(prompt);
	return io.stdin:read "l";
end

local vars = {};

while true do
	local action = readline "Action to perform [retrieve most recent value/notify about value update/cleanly exit this program]: ";

	if action == "retrieve most recent value" then
		local name = readline "Variable's name to get the value of: ";
		print(vars[name]);
	elseif action == "notify about value update" then
		local name = readline "Variable's name to update the value of: ";
		local val = readline "New value to apply to the variable: ";
		vars[name] = val;
	elseif action == "cleanly exit this program" then
		os.exit();
	elseif action == "get" or action == "set" or action == "exit" then
		print "If you are looking for an intuitive experience, you are in the wrong place";
		os.exit();
	else
		print "You have misused this program beyond repair, and now it shall exit";
		print "(without telling you the variable names)";
		os.exit();
	end
end
