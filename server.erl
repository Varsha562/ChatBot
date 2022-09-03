-module(server).
-behaviour(gen_server).
-include_lib("stdlib/include/qlc.hrl").
-export([svr_node/0, start/0, logon/1, logoff/0, list_of_all_users/0, messageTo/2, groupMessage/1, delete_table/0, storeUserDB/3,storeMessageDB/4, findUserName/1, listOfActiveUsers/0, findPid/1, getUserMsgs/1, retrive_top_N_msgs/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-record(userList, {clientPid, name, status}).
-record(messageList, {from, to, message, sentTime}).
-record(state,{}).

svr_node() ->
    server5@ggn002156.

start() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [[]], []).
	
init(_Args) ->
        %io:format("executedinit~n"),
        initDB(),
	{ok, #state{}}.

initDB() ->
	mnesia:create_schema([node()]),
	mnesia:start(),
	try
		mnesia:table_info(start, userList)
	catch
		exit: _->
		mnesia:create_table(userList, [{attributes, record_info(fields, userList)}, {type, bag}, {disc_copies, [node()]}])
	end,
	
	try
		mnesia:table_info(start, messageList)
	catch
		exit: _->
		mnesia:create_table(messageList, [{attributes, record_info(fields, messageList)}, {type, bag}, {disc_copies, [node()]}])
	end.
	
logon(Name) ->
        %io:format("executed~n"),
	gen_server:call({global, ?MODULE}, {logon, Name}).

logoff() ->
        gen_server:call({global, ?MODULE}, logoff).

delete_table() ->
        gen_server:call({global, ?MODULE}, delete_table).

list_of_all_users() ->
        gen_server:call({global, ?MODULE}, list_of_all_users).
        
messageTo(To, Message) ->
	gen_server:call({global, ?MODULE}, {messageTo, To, Message}).

groupMessage(Message) ->
        gen_server:call({global, ?MODULE}, {groupMessage, Message}).
	
storeUserDB(ClientPid, Name, Status) ->
	UF = fun() ->
		mnesia:write(#userList{clientPid = ClientPid, name = Name, status = Status})
	     end,
	mnesia:transaction(UF).

storeMessageDB(From, To, Message, Time) ->
	MF = fun() ->
		mnesia:write(#messageList{from = From, to = To, message = Message, sentTime = Time})
	     end,
	mnesia:transaction(MF).

updateStatus(ClientPid, Status) ->
	fun() ->
		[P] = mnesia:wread({userList, ClientPid}),
		mnesia:write(P#userList{clientPid=ClientPid, status=Status})
	end.
	
findUserName(UserName) ->
	UF = fun() ->
		Query = qlc:q([X || X <- mnesia:table(userList), X#userList.name =:= UserName]),
	        case qlc:e(Query) of
	        [P] ->
			P;
		_ ->
			[]
	     	end
	     end,
	{atomic, Result} = mnesia:transaction(UF),
	Result.
	
listOfActiveUsers() ->
	UF = fun() ->
		Query = qlc:q([X || X <- mnesia:table(userList), X#userList.status =:= "Active"]),
		Results = qlc:e(Query), 
		Results
	     end,
	{atomic, Result} = mnesia:transaction(UF),
	Result.
	
findPid(ClientPid) ->
	UF = fun() ->
		Query = qlc:q([X || X <- mnesia:table(userList), X#userList.clientPid =:= ClientPid]),
		case qlc:e(Query) of
			[P] ->
			 	P;
			_ ->
			 	[]
		end
	     end,
	{atomic, Result} = mnesia:transaction(UF),	
	Result.
	
getUserMsgs(UserName) ->	
	MF = fun() ->
		Results = mnesia:select(messageList, [{{messageList, '_', '$1', '_', '_'},[{'orelse', {'=:=', '$1', UserName},{'=:=','$1', "Everyone"}}], ['$_']}]),
		Results
	     end,
	{atomic, Result} = mnesia:transaction(MF),
	Result.

deleteDB() ->
	mnesia:delete_table(userList),
	mnesia:delete_table(messageList),
	mnesia:delete_schema([node()]).
		
handle_call({logon, Name}, From, State) ->
%% check if logged on anywhere else
	%io:format("Message from ~p", [From]),
	{Client, _Ref} = From,
	Response = findPid(Client),
        case Response =:= [] of
        	false ->
        	     {_, _, _, Status} = Response,
        	     case Status =:= "Active" of
        	     	true ->
        	     		{reply, "Already logged on!", State};  %reject logon
        	     	false ->
        	     		updateStatus(Client, "Active"),%update clientpid
        	     		Message = "I have logged in the room",
				storeMessageDB(Name, "Everyone", Message, calendar:local_time()),
				NewMessageList = getUserMsgs(Name),
				Messages = retrive_top_N_msgs(Name, NewMessageList, [], 10),
				UserList = listOfActiveUsers(),
			  	send_all(UserList, Client, Name, Message),
				{reply, Messages, State}
		      end;
        	true ->
	       	UserList = listOfActiveUsers(),
			Length = length(UserList),
			case Length >= 10 of
				true ->
					{reply, "Oops, room is full!", State};  %reject logon
				false ->
				        Resp = findUserName(Client),
					case Resp =:= name_exists of
						true ->
							 {reply, "UserName is taken!", State}; %reject logon
						false ->
							%add user to the list
							storeUserDB(Client, Name, "Active"),
							Message = "I have logged in the room",
							storeMessageDB(Name, "Everyone", Message, calendar:local_time()),
							MessageList = getUserMsgs(Name),
							Messages = retrive_top_N_msgs(Name, MessageList, [], 10),
							NewUserList = listOfActiveUsers(),
						  	send_all(NewUserList, Client, Name, Message),
							{reply, Messages, State}
					end
			end
	end;

%%% Server deletes a user from the user list
handle_call(logoff, From, State) ->
	{Client, _Ref} = From,
	Response = findPid(Client),
        case Response =:= [] of
		true ->
			{stop, normal, "No username exists!", State};
		false ->
		        {_, _, Name, Status} = Response,
		        case Status =:= "Inactive" of
		        	true ->
		        		{stop, normal, "You are not logged on!", State};
		        	false ->		        	
					Message = "I have logged out",
					storeMessageDB(Name, "Everyone", Message, calendar:local_time()), 
					updateStatus(Client, "Inactive"),
					UserList = listOfActiveUsers(),
					send_all(UserList, Client, Name, Message),
					{reply, "Success", State}
			end
	end;
	
handle_call(delete_table, From, State) ->
	{Client, _Ref} = From,
	Response = findPid(Client),
        case Response =:= [] of
		true ->
			{stop, normal, "No username exists!", State};
		false ->
		        {_, _, _Name, Status} = Response,
		        case Status =:= "Inactive" of
		        	true ->
		        		{stop, normal, "You are not logged on!", State};
		        	false ->		        	
					deleteDB(),
					{reply, "Success", State}
			end
	end;
	
handle_call(list_of_all_users, From, State) ->
        {Client, _Ref} = From,
	Response = findPid(Client),
        case Response =:= [] of
		true ->
			{stop, normal, "No username exists!", State};
		false ->
			{_, _, _Name, Status} = Response,
		        case Status =:= "Inactive" of
		        	true ->
		        		{stop, normal, "You are not logged on!", State};
		        	false ->
		        	        UserList = listOfActiveUsers(),
		        	             	
					users(Client, UserList),
					{reply, "ok", State}
			end
	end;

handle_call({messageTo, To, Message}, From, State) ->
        %io:format("Hello~n"),
    	{Client, _Ref} = From,
	Response = findPid(Client),
        case Response =:= [] of
		true ->
			{stop, normal, "No username exists!", State};
		false ->
			{_, _, Name, Status} = Response,
		        case Status =:= "Inactive" of
		        	true ->
		        		{stop, normal, "You are not logged on!", State};
		        	false ->
		        	 	R = findUserName(To),		        	
					case R =:= [] of
						true ->
							{reply,"Receiver not found!", State};
						false ->
						        {_, ToPid, _, _} = R,
							storeMessageDB(Name, To, Message, calendar:local_time()),
							ToPid ! {messageFrom, Name, To, Message, calendar:local_time()}, 
							{reply,"Sent", State}
					end
			end
	end;

handle_call({groupMessage, Message}, From, State) ->
        %io:format("Hellooo~n"),
	{Client, _Ref} = From,
	Response = findPid(Client),
        case Response =:= [] of
		true ->
			{stop, normal, "No username exists!", State};
		false ->
			{_, _, Name, Status} = Response,
		        case Status =:= "Inactive" of
		        	true ->
		        		{stop, normal, "You are not logged on!", State};
		        	false ->
		        		{_, _, Name, _} = Response,
					storeMessageDB(Name, "Everyone", Message, calendar:local_time()),
					UserList = listOfActiveUsers(),
					send_all(UserList, Client, Name, Message),
					{reply, "Sent", State}
			end
	end;
	
handle_call(_, _From, State) ->
	%io:format("executecall~n"),
	{reply,"hi",State}.
	
handle_cast(stop, State) ->
	{stop, normal, State};

handle_cast(_Request, State) ->
	{noreply, State}.
	
handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	io:format("terminating ~p~n", [{global, ?MODULE}]),
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.
	
%%% retrieving msgs
retrive_top_N_msgs(_Name, [], M, _Cap) -> M;
retrive_top_N_msgs(_Name, _MessageList, M, 0) -> M;
retrive_top_N_msgs(Name, [H|T], M, Cap) ->
	{_, _From, To, _Message, _Time} = H,
	case To == "Everyone" of
		true ->
			retrive_top_N_msgs(Name, T, [H|M], Cap-1);
		false ->
			case To == Name of
				true ->
					retrive_top_N_msgs(Name, T, [H|M], Cap-1);
				false ->
					retrive_top_N_msgs(Name, T, M, Cap)
			end
	end.

users(_From, []) ->
	  done;
	  
users(From, [H|T]) ->
	{_, _Pid, Name, _} = H,
	From ! {messageFrom, Name},
	users(From, T). 

%%% Looping to send message to all users   
send_all([], _From, _Name, _Message) ->
	done;
send_all([H|T], From, Name, Message) ->
        %io:format("send_done ~n"),
	{_, ToPid, _To, _} = H, 
	ToPid ! {messageFrom, Name, "Everyone", Message, calendar:local_time()},
	send_all(T, From, Name, Message). 
	
	
