-- show top 100 players

if not init then
	

	
	-- get all players with level < 3
	ret = {};
	for i = 1,#players do
		if players[i][2]<3 then ret[#ret+1] = players[i][3] end  
	end
	book.write(1,"",table.concat(ret,",")) -- write output to book
	
	