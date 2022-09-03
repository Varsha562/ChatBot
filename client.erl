-module(client).
-export([logon/1, logoff/0, messageTo/2, groupMessage/1, cli/0, list_of_all_users/0, delete_table/0]).
-import(server, [svr_node/0]).

%%% User Commands
logon(Name) ->
	case whereis(mess_reg) of 
        	undefined ->
            		register(mess_reg, spawn(client, cli, [])),
            		mess_reg ! {logon, Name};
        	_ -> "Aready logged on!"
    	end.

	

logoff() -> 
	case whereis(mess_reg) of 
        	undefined ->
            		"You are not logged on!";
            	_ -> mess_reg ! logoff
    	end.
	

list_of_all_users() -> 
	case whereis(mess_reg) of 
        	undefined ->
            		"You are not logged on!";
            	_ -> mess_reg ! list_of_all_users
    	end.
	
    
messageTo(To, Message) ->
	case whereis(mess_reg) of 
        	undefined ->
            		"You are not logged on!";
            	_ -> mess_reg ! {messageTo, To, Message}
    	end.
    
groupMessage(Message) ->
	case whereis(mess_reg) of 
        	undefined ->
            		"You are not logged on!";
            	_ -> mess_reg ! {groupMessage, Message}
    	end.	
    	
delete_table() ->
	case whereis(mess_reg) of 
        	undefined ->
            		"You are not logged on!";
            	_ -> mess_reg ! delete_table
    	end.

cli() ->
	receive
		{logon, Name} ->
		   	Reply = gen_server:call({server, svr_node()}, {logon, Name}),
		   	io:format("~p~n", [Reply]);
		logoff ->
		        Reply = gen_server:call({server, svr_node()}, logoff),
		        io:format("~p~n", [Reply]);
		delete_table ->
		        Reply = gen_server:call({server, svr_node()}, delete_table),
		        io:format("~p~n", [Reply]);
		list_of_all_users ->
			Reply = gen_server:call({server, svr_node()}, list_of_all_users),
			io:format("~p~n", [Reply]);
		{messageTo, To, Message} ->
		        Reply = gen_server:call({server, svr_node()}, {messageTo, To, Message}),
		        io:format("~p~n", [Reply]);
		{groupMessage, Message} ->
			Reply = gen_server:call({server, svr_node()}, {groupMessage, Message}),
			io:format("~p~n", [Reply]);
		{messageFrom, From, To, Message, Time} ->
			io:format("Message from ~p to ~p: ~p at ~p~n", [From, To, Message, Time]);
		{messageFrom, Name} ->
			io:format("~p~n", [Name])
	end,
cli().

